Unit MP11;
{$M 16384, 0, 500000}
{$R-,N-,E-,G+,A+}
{Speed + BPM OK!}
{Pattern Break OK!}
{386-only}
{DMA -> Recseg}
{Optimalgatott}

{ $DEFINE XDMA}

Interface

Type SampleType = Record
       Nev   : Array [0..21] of Char;
       Hossz : Word;
       Tune  : ShortInt;
       DefVol: Byte;
       LoopS : Word;
       LoopL : Word; {Loop Hossz -> ha 1, nincs loop!}
     end;

Type ModHeader = Record
       Nev      : Array [0..19] of Char;
       Sample   : Array [0..30] of SampleType;
       NumOrders: Byte;
       ID       : Byte; {CIAA-SPeed ?...}
       Order    : Array [0..127] of Byte;
       MK       : Array [0..3] of Char;
     end;

Type CHNDataType = Record
       InsP   : Byte;      {Melyik hangszer szol}
       SFreq  : LongInt;   {Hang frekvenciaja}
       Step16 : LongInt;   {Lepeskoz}
       HPoz16 : LongInt;   {Pozicio a hangban}
       ChnVol : Word;      {Csatorna hangereje}
       CVol   : Byte;      {Kimeneti Hangero a csatornan}
       TonePort: Word;     {Tone portamento's speed}
       VolSlide: Byte;
       FillEmpty: Array [0..12] of Byte {kitoltesnek}
    end;

Const EngineVerzio = '1.11';
      AlapHZ    = 8363;
      FreqConst = AlapHZ*428; {AlapHZ/C-2 Hertz!}
      MixHZ     : Word = 16000;
      MaxCHN    = 16;
      AllChn    : Byte = 4;
      MusCHN    : Byte = 4;
      BPM       : Byte = 125;
      Speed     : Byte = 6;
      Stop      : Boolean = False;
      BuffSize  = 8000; {DMA-Buffer}
      BitX      = 15; {65535 HZ feletti hangokhoz 14-re kell modositani}
      Period    : Array [0..35] of Word =
                   (856,808,762,720,678,640,604,570,538,508,480,453,
                    428,404,381,360,339,320,302,285,269,254,240,226,
                    214,202,190,180,170,160,151,143,135,127,120,113);
      SinTable  : Array [0..31] of Byte =
                   (0,25,50,74,98,120,142,162,180,197,212,225,
                    236,244,250,254,255,254,250,244,236,225,
                    212,197,180,162,142,120,98,74,50,25);


Var SorPos     : Byte;
    AktPatt    : Byte;
    ModFejlec  : ModHeader;
    NumPatterns: Byte;
    Pattern    : Array [0..63] of Pointer;
    MasterVol  : Integer;
    DMAOK      : Boolean;
    SBIntSzam  : LongInt; {Hanyszor hivodott meg az SB interrupt-ja}
    MixW       : Word;
    CHNData    : Array [0..MaxChn-1] of CHNDataType;
    M16        : Array [0..30] of LongInt; {16x Hangszer meretek}
    LS16       : Array [0..30] of LongInt; {16x loopstart}
    LE16       : Array [0..30] of LongInt; {16x loopend}
    BuffP      : Word;
    BuffUp     : Word;
    XCounter   : LongInt;
    SorGy      : Byte; {Mindig egyenlo MUSHCN SHL 2 - vel !!!}

Function InitMixer: Boolean;
Procedure SetMixSpeed;
Procedure DeInitMixer;
Function  ModToltes (ModNev: String):Boolean;
Procedure DeInitModule;

Implementation

Uses DMA, Dos;
{$I DUTIMER.INC}
{$I LONG.INC}
{$I SB.INC}

Const DMAEndP      = $0F;

Type BuffType = Array [0..BuffSize-1] of Byte;

{Type PatternType = Array [0..63] of Array [0..3] of Array [0..3] of Byte;}

Var P    : Pointer;
    F    : File;
    D    : Integer;
    Bajt : Byte;

    OldSB  : Pointer;

    DMABuff: Array [False..True] of BuffType;
    DMAS   : Boolean;

    Ins      : Array [0..30] of Pointer; {Hangszer adatok}
    InsL     : Array [0..30] of Boolean; {Loopolas-i adatok}

    PlayerHZ : Word; {Hany HZ-enkent hivodik meg a Player}
    SorHZ    : Word;
    SorHZP   : Word;
    SpeedP   : Byte;

Function ModToltes (ModNev: String):Boolean;
{MOD-ot tolt be}
Var F: File;
    I: Byte;
    J: Byte;
    H: Word;
    K: Byte;
    P: Pointer;
    Hiba: Boolean;
    SampleSzam: Word;
  Procedure Csere (Var Mit: Word);
  begin
    Mit := Swap (Mit) shl 1;
  end;
begin
  Hiba := False;
  ModToltes := False;
  SampleSzam := 30;
  Assign (F, ModNev);
  {$I-}
  Reset (F, 1);
  {$I+}
  If IOResult = 0 then
  begin
    With ModFejlec Do
    begin
      BlockRead (F, ModFejlec, Sizeof (ModFejlec));
      If MK = '2CHN' then MusCHN := 2 else
      If (MK = 'M.K.') or (MK = 'FLT4') then MusCHN := 4 else
      If MK = '6CHN' then MusCHN := 6 else
      If MK = '8CHN' then MusCHN := 8 else
      If MK = '10CH' then MusCHN := 10 else
      If MK = '12CH' then MusCHN := 12 else
      If MK = '14CH' then MusCHN := 14 else
      If MK = '16CH' then MusCHN := 16 else
        Hiba := True; {Ismeretlen MOD-file}

      If not Hiba then
      begin

      For I := 0 to SampleSzam Do
      begin
        Csere (Sample [I].Hossz);
        Csere (Sample [I].LoopS);
        Csere (Sample [I].LoopL);
        If Sample [I].LoopL = 0 then Sample [I].LoopL := 2;
        If Sample [I].LoopL = 2 then InsL [I] := False else InsL [I] := True;
      end;

      NumPatterns := 0;
      For I := 0 to 127 Do If Order [I] > NumPatterns then NumPatterns := Order [I];
      For I := 0 to NumPatterns Do GetMem (Pattern [I], MusCHN*4*64);
      For I := 0 to NumPatterns Do BlockRead (F, Pattern [I]^, MusCHN*4*64);

      For I := 0 to MaxChn-1 Do
      With CHNData [I] Do
      begin
        InsP := 0;
        SFreq := AlapHZ;
        Step16 := 0;
        HPoz16 := 0;
        CHNVol := 0;
      end;

      For I := 0 to SampleSzam Do
      begin
        H := Sample [I].Hossz;

        M16 [I] := LongInt (Sample [I].Hossz) shl BitX;
        LS16 [I] := LongInt (Sample [I].LoopS) shl BitX;
        If Sample [I].LoopL > 2 then
          LE16 [I] := LongInt (Sample [I].LoopS+Sample [I].LoopL) shl BitX
            else LE16 [I] := 0;

        If H > 0 then
        begin
          GetMem (P, H);
          BlockRead (F, P^, Sample [I].Hossz);
          asm
            les di, p
            mov cx, h
            @cikli:
              mov al, es:[di]
              xor al, 127
              stosb
            loop @cikli
          end;
          Ins [I] := P;
        end;
      end;

      end;
    end;
    Close (F);
    ModToltes := True;
  end;
  SorGy := MusCHN shl 2;
  If Hiba then ModToltes := False;
end;

Procedure DMAEnd;Interrupt;
begin
  {Tudomasul vetel}
  asm mov dx, DSP_DATA_AVAIL;in al, dx end;
  DMAOk := True;
  Inc (SBIntSzam);
  asm mov al, 020h;out 020h, al end;
end;

Type HangTip = Array [0..3] of Byte;

Var HPoz    : Word;
    Hangjegy: Word;
    XSMP    : Byte;
    FX      : Byte;
    Comm    : Byte;
    Xxx     : Byte;
    Temp    : Word;
    EComm   : Byte;
    x        :  Word;

Procedure Sorjatszik;
begin
  If not Stop then
  begin
    asm
      inc speedp
    end;

    For D := 0 to MusCHN-1 Do
    begin
      asm
        lea si, modfejlec {Y = ModFejlec.Order [AktPatt]}
        add si, 952
        xor ah, ah
        mov al, aktpatt
        add si, ax
        mov al, ds:[si]
        xor ah, ah     {ax = Y}
        {---}
        lea si, pattern
        add ax, ax
        add ax, ax
        add si, ax
        {---}
        lodsw;mov word ptr [p], ax   {P := Pattern [y];}
        lodsw;mov word ptr [p+2], ax
        {---}
        xor ah, ah {X =(SorPos*SorGy)+D shl 2)^);}
        xor dh, dh
        mov al, sorpos
        mov dl, sorgy
        mul dl
        mov bx, d
        add bx, bx
        add bx, bx
        add ax, bx {AX = X}
        {---}
        mov cx, ds {XHang := HangTip (Ptr (Seg (P^),Ofs (P^)+X)^);   }
        mov es, cx
        mov bx, word ptr [p]
        mov si, bx {AX = X OVER!}
        add si, ax
        mov ax, word ptr [p+2]
        mov ds, ax

        lodsw
        mov byte ptr es:[hangjegy], ah {Hangjegy := Word ((XHang [0] and $0F) shl 8+XHang [1]);}
        mov byte ptr es:[hangjegy+1], al
        and word ptr es:[hangjegy], $0FFF

        and al, $F0 {XSMP := (XHang [0] and $F0)+(XHang [2] shr 4)-1;}
        mov byte ptr es:[xsmp], al {XSMP = XHANG [0]}

        lodsw

        mov es:[fx], al {FX := (XHang [2] and 15);}
        and es:[fx], 15
        mov es:[comm], ah {Comm := XHang [3];}

        shr al, 4 {XSMP += +(XHang [2] shr 4)-1;}
        dec al
        add byte ptr es:[xsmp], al

        mov ds, cx
      end;
      {VIGYAZAT!}
    If SpeedP >= Speed then
    BEGIN
      If Hangjegy > 0 then
      begin
        If (XSMp < 32) then CHNData [D].InsP := XSMP;
        If FX <> 03 then
        With CHNData [D] Do
        begin
          asm
            lea si, chndata {X = chndata [d].insp}
            mov ax, d
            shl ax, 5
            add si, ax
            mov BX, SI      {BX-be mentjuk az SI-T}
            mov dl, ds:[si] {DL = X}
            {---}
            lea si, modfejlec  {X := DefVol shl 2}
            add si, 20+25
            xor dh, dh
            mov ax, 30
            mul dl
            add si, ax
            mov al, ds:[si]
            add ax, ax
            add ax, ax
            {---}
            mov SI, BX    {Eddig kellet BX! CHNVol := x;}
            add si, 13
            mov word ptr ds:[si], ax
            {---}
          end;
          If CHNdata [D].CHNVol > 256 then CHNData [D].CHNVol := 256;
          SFreq := FreqConst div Hangjegy;
          Step16 := (LongInt (LongInt (SFreq) shl BitX)) div MixHZ;
          HPoz16 := 0;
        end;
      end;
      {Egyszer hasznalatos FX-ek}
      Case FX of
        09: begin {Sample offset}
              {Alap=*256+CHNDATA = shl 8}
              ChnData [D].HPoz16 := LongInt (Comm) shl (BitX+8);
            end;
        10: begin {Volume Slide}
              If Comm > 0 then ChnData [D].VolSlide := Comm;
              Inc (CHNData [D].ChnVol, (CHNdata [D].VolSlide and 240) shl 2);
              Xxx := (ChnData [D].VolSlide and 15) shl 2;
              If Xxx < CHNData [D].ChnVol then Dec (CHNData [D].ChnVol, Xxx)
                else CHNData [D].ChnVol := 0;
              If CHNdata [D].CHNVol > 256 then CHNData [D].CHNVol := 256;
            end;
        11: begin
              AktPatt := Comm-1;
              SorPos := 63;
            end;
        12: begin {Set Volume}
              CHNData [D].CHNVol := Comm shl 2;
              If CHNdata [D].CHNVol > 256 then CHNData [D].CHNVol := 256;
            end;
        13: begin {Pattern Break}
              SorPos := 63;
            end;
        14: begin {E-commands}
              EComm := Comm and $0F;
              Case ((Comm and $F0) shr 4) of
                10: {Volume fine-slide up}
                    If CHNData [D].CHNVol+(EComm shl 1) < 256 then
                      Inc (CHNData [D].CHNVOl, EComm shl 1)
                        else CHNData [D].CHNVol := 256;
                11: {Volume fine-slide down}
                    If CHNData [D].CHNVol > EComm shl 1 then
                      Dec (CHNData [D].CHNVOl, EComm shl 1)
                        else CHNData [D].CHNVol := 0;
              end;
            end;
        15: begin {Set Speed}
              If Comm < $20 then
              begin
                If Comm > 0 then Speed := Comm;
              end else BPM := Comm;
              PlayerHZ := (BPM shl 1) div 5;
              SorHZ := (MixHZ div PlayerHZ);
            end;
      end;
    END;

    {Hivasonkent valtozo FX-ek!}
    Case FX of
      03: begin {Tone Portamento}
            With CHNData [D] Do
            begin
              If HangJegy > 0 then Temp := FreqConst div Hangjegy;
              If Comm > 0 then TonePort := Comm;
              If SFreq < Temp then
              begin
                Inc (SFreq, TonePort*PlayerHZ);
                If SFreq > Temp then SFreq := Temp;
                Step16 := (LongInt (SFreq) shl BitX) div MixHZ;
              end;
              If SFreq > Temp then
              begin
                Dec (SFreq, TonePort*PlayerHZ);
                If SFreq < Temp then SFreq := Temp;
                Step16 := (LongInt (SFreq) shl BitX) div MixHZ;
              end;
            end;
          end;
      end;

  end;

  If SpeedP >= Speed then
  begin
    asm
      inc sorpos
    end;
    If SorPos = 64 then
    begin
      asm
        mov sorpos, 0
        inc aktpatt
      end;
      If AktPatt > ModFejlec.NumOrders-1 then AktPatt := 0;
    end;
    asm
      mov speedp, 0
    end;
  end;

  end;
end;


Procedure DMAOutPut;
begin
  {*** DMA-s KIKULDES ***}
  DMABuff [DMAS][BuffP] := Byte (MixW);
  Inc (BuffP);
  If BuffP > BuffSize-1 then DMAOk := True;
  If (BuffP > BuffSize shr 1) and (DMAOK) then
  begin
    PlayBack (@DMABuff [DMAS], BuffP);
    BuffUp := BuffP;
    BuffP := 0;
    DMAS := not DMAS;
    DMAOK := False;
  end;
end;

Var xx : LongInt;
    yy : LongInt;
    zz : LongInt;
    IP : Word;
 {   BExx: Word; = CX !}
    Be32: Word;
    C   : Word;

Procedure Mixer;Interrupt;Assembler;
  asm
    pusha

    db 066h;inc word ptr [xcounter] {Inc (XCounter);}
    inc sorhzp  {Inc (SorHZP);}

    mov ax, sorhz
    cmp sorhzp, ax
    jb @vege
      mov sorhzp, 0 {Ha SorHZP >= SorHZ}
      call sorjatszik
    @vege:

    mov mixw, 0

      {********************** FO-MIXER CIKLUS *************************}
      {FENNTARTOTT (nem hasznalhato MASRA): CX (= BExx valtozo) !}
      mov c, 0
      @MAINCIKLUS:

      lea si, chndata  {    IP := CHNData [C].InsP;}
      mov ax, c        {    xx := CHNData [C].HPoz16;}
      shl ax, 5
      add si, ax
      mov BE32, ax
      lodsb {akkor SI ugye novelodik!}
      xor ah, ah
      mov ip, ax {IP BETOLTESE}
      add si, 8
      mov CX, si
      db 066h;mov ax, word ptr ds:[si] {XX betoltese}
      db 066h;mov word ptr xx, ax
      (*lodsw;mov word ptr xx, ax;mov ax, ds:[si];mov word ptr [xx+2], ax*)
      {----}
      lea si, m16
      mov ax, ip
      add ax, ax
      add ax, ax
      add si, ax  {    yy := M16 [IP];}
      db 066h;mov ax, word ptr ds:[si]
      db 066h;mov word ptr yy, ax
      (*lodsw;mov word ptr yy, ax;mov ax, ds:[si];mov word ptr [yy+2], ax*)
      {---}

      {----- VAN-E HANG? -----}
      db 066h;mov ax, word ptr xx
      db 066h;cmp ax, word ptr yy
      jg @NINCSHANG

      {**** VAN HANG ****}
      {ES:DI = DS:INS [INSP]}
      lea si, ins     {Hangszer-pointer beallitasa}
      mov ax, ip
      add ax, ax
      add ax, ax
      add si, ax
      {---}
      lodsw;mov di, ax {offset beallitas}
      lodsw;mov es, ax {segment beallitas}
      {---}
      {Bajt := Byte (Ptr (Seg (P^), Ofs (P^)+xx shr BitX)^);}
      db 066h;mov ax, word ptr [xx]
      db 066h;shr ax, BitX
      add di, ax {cimhozzaadas}
      mov al, es:[di] {BAJT-ba toltes}
      {*** AL = BYTE ***}
      {---}
      lea si, chndata  {CV := CHNdata [C].CHNVol;}
      add si, be32 {SIZEOF CHNDATATYPE}
      add si, 13
      mov dx, word ptr ds:[si]
      {*** DX = CV ***}
      {---}
      {Bajt := (Word (Bajt)*(CHNData [C].ChnVol)) shr 8;}
      xor ah, ah {---- AL, DX OLDVA}
      mul dx
      mov al, ah
      xor ah, ah {AL = BAJT}
      {---}
      {Inc (MixW, Bajt);}
      add mixw, ax
      {---}
      inc si {CHNData [C].CVol := Bajt;}
      inc si
      mov ds:[si], al
      {---}
      mov si, CX {Inc (Longint (CHNData [C].HPoz16), LongInt (CHNData [C].Step16));}
      sub si, 4
      db 066h;mov bx, word ptr ds:[si] {EBX = Step16; megvan}
      add si, 4
      db 066h;add ds:[si], bx

      {*** LOOP ellenorzes ***}
      lea si, insl
      add si, ip
      mov al, ds:[si]
      cmp al, false
      je @nemloop

      {zz := LE16 [IP];}
      lea si, le16
      mov ax, ip
      add ax, ax
      add ax, ax
      add si, ax
      db 066h;mov ax, word ptr ds:[si]
      db 066h;mov word ptr zz, ax
      {---}
      {xx := ChnData [C].HPoz16;}
      mov si, CX
      db 066h;mov ax, word ptr ds:[si] {XX betoltese}
      db 066h;mov word ptr xx, ax
      {------------ Loopolas -------------}
      db 066h;mov ax, word ptr xx  {If xx > zz then}
      db 066h;mov bx, word ptr zz
      db 066h;cmp ax, bx
      jbe @nemloop
      {---}
      {db 066h;mov ax, word ptr xx {yy := xx - zz;}
      db 066h;sub ax, bx
      db 066h;mov word ptr yy, ax
      {---}
      lea si, ls16 {CHNData [C].HPoz16 := LS16 [IP]+yy;}
      mov ax, ip
      add ax, ax
      add ax, ax
      add si, ax
      db 066h;mov bx, word ptr ds:[si]
      db 066h;add bx, word ptr yy {Ez a sor lehet hogy nem kell!}
      mov si, CX
      db 066h;mov word ptr ds:[si], bx
      @nemloop:
      jmp @HANGVEGE

      @NINCSHANG:
      {**** Nincs hang ****}
      lea si, chndata {CHNData [C].CVol := 127;}
      add si, be32
      add si, ax
      add si, 15
      mov al, 127
      mov ds:[si], al
      {---}
      add mixw, 127 {Inc (MixW, 127);}

      @HANGVEGE:

      inc c
      mov al, allchn
      cmp byte ptr c, al
      jb @MAINCIKLUS
      {*************************** END OF MAIN-MIXER **********************}

  {*** Hangero <> MasterVolume+Csatornaszam; leosztas ***}
  {mixw := ((MixW*MasterVol) div AllCHN);}
  mov ax, mixw
  mov bx, mastervol
  mul bx {dx:ax = mixw*mastervol}
  xor bh, bh
  mov bl, allchn
  div bx {AX-ben az eredmeny}
  {---}
  mov al, ah
  xor ah, ah {mixw = mixw shr 8}
  mov mixw, ax

  {$IFDEF XDMA}
  call dmaoutput
  {$ELSE}
  {*** DIREKT KIKULDES ***}
  mov bl, byte ptr mixw
  call sbbyteout
  {$ENDIF}

 {call biosthings
  cmp voltbios, true
  je @legvege}
  mov al, 020h;
  out 020h, al;
  @legvege:
  {*** Megszakitas vege ***}
  popa
end;

Procedure MixSet;
begin
  {HZ korrekcio}
  MixHZ := 1000000 div (1000000 div MixHZ);
  {---}
  SetTimer (@Mixer, MixHZ);
  PlayerHZ := (BPM shl 1) div 5;
  SorHZ := (MixHZ div PlayerHZ);
  {$IFDEF XDMA}
  If DMAOk then
  begin
    DMAStop;
    SpeakerOff;
    WriteDSP($40);
    WriteDSP(256 - (1000000 div MixHZ));
    SpeakerOn;
    DMAContinue;
  end;
  {$ENDIF}
end;

Procedure SetMixSpeed;
begin
  CleanUpTimer;
  MixSet;
end;

Function InitMixer: Boolean;
begin
  {$IFDEF XDMA}
  If ResetDSP (2) then
  begin
    GetIntVec (DmaEndP, OldSB);
    SetIntVec (DmaEndP, @DMAEnd);
    DMAOk := True;
    InitMixer := True;
  end else InitMixer := False;
  {$ELSE}
  If InstallSoundBlaster = 0 then InitMixer := True else InitMixer := False;
  {$ENDIF}
  MixSet;
end;

Procedure DeInitMixer;
begin
  CleanUpTimer;
  {$IFDEF XDMA}
    SpeakerOff;
    SetIntVec (DmaEndP, OldSB);
  {$ENDIF}
end;

Procedure DeInitModule;
Var I: Byte;
begin
  For I := 0 to 30 Do
  begin
    If ModFejlec.Sample [I].Hossz > 0 then
      FreeMem (Ins [I], ModFejlec.Sample [I].Hossz);
  end;
end;

End.