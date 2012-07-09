Program DL04;


Uses DU, DUTypes, DLTitle, Mp11;

{$I DUMCGA.INC}
{$I FTRI.INC}

Const CsSzam = 1000;

Var Pal: RGBMap;
    I  : Word;
    J  : Word;
    F  : Integer;
    G  : Integer;
    H  : Integer;
    B  : Byte;
    FP, AP: Word;
    XC, YC: Array [0..CsSzam] of Integer;
    XM    : Array [0..CsSzam] of Byte;
    XE    : Array [0..CsSzam] of Byte;
    SM    : Array [0..15] of Byte;
    zz    : Integer;

Procedure Csillam (x,y,m,e: Integer);
Var I: Byte;
    B: Byte;
    z: Integer;
begin
  If m > 0 then
  For I := 0 to m-1 Do
  begin
    z := -(m shr 1)+i;
    B := Hatter^[x+sor [y]-z];
    Inc (B, M);If B > E then B := E;
    Hatter^[x+sor [y]-z] := B;

    B := Hatter^[x+sor [y-z]];
    Inc (B, M);If B > E then B := E;
    Hatter^[x+sor [y-z]] := B;
  end;
end;

Begin
  MixHZ := 8000;
  If ModToltes ('title.mod') then
  begin
    MasterVol := 256;
    InitMixer;
  end else
  begin Writeln ('SB init error.');Halt (0);end;
  MCGAINIT;
  GrOn;
  New (Hatter);
  For I := 0 to 15 Do SM [I] := Trunc (Sin (I/(15/Pi))*10);
  Move (Ptr (Seg (DLKep), Ofs (DLKep)+40+32)^, Pal, 768);
  For I := 0 to 255 Do With Pal [I] Do begin R := R shr 2;G := G shr 2;B := B shr 2;end;
  SetRGBPal (Pal);
  {Move (Ptr (Seg (DLKep), Ofs (DLKEp)+846)^, VHatter, 64000);}
  F := 0;
  Repeat
    HCLS;
    F := XCounter div 156;
    If F < 0 then F := 0;
    G := F-320;
    If (g > 0) and (g < 319) then
    BEGIN
      FP := 30;
      AP := 130;
      While (Byte (Ptr (Seg (DLKep), Ofs (DLKEp)+846+Sor [FP]+g)^) = 0) Do Inc (FP);
      While (Byte (Ptr (Seg (DLKep), Ofs (DLKEp)+846+Sor [AP]+g)^) = 0) Do Dec (AP);
      If FP < 130 then
      begin
        asm cli;end;
        FTri (Hatter,159,99,g,FP,g,AP,20);
        asm sti;end;
      end;
    {DeadLock}
    For I := 70 to 130 Do
    begin
      For J := 0 to G Do
      begin
        {B := Byte (Ptr (Seg (DLKep), Ofs (DLKEp)+846+Sor [I]+J)^);}
        {If B <> 0 then Hatter ^[Sor [I]+J] := B;}
        asm
          lea si, sor
          mov cx, i
          add cx, cx
          add si, cx
          mov bx, ds:[si]
          add bx, j

          mov ax, seg dlkep
          mov es, ax
          mov di, 846
          add di, bx
          mov al, es:[di] {=szin}

          cmp al, 0
          jz @vege
            les di, hatter
            add di, bx
            mov es:[di], al
          @vege:
        end;
      end;
    end;
    END;
    If G >= 319 then
    begin
      Move (Ptr (Seg (DlKep),Ofs (DlKep)+846+320*70)^,
        Ptr (Seg (Hatter^), Ofs (Hatter^)+320*70)^, 320*60);
    end;
    {Csillamok}
    H := F;
    If H > 319 then H := 319;
    zz := g;
    If zz < 0 then zz := 0;

    For I := 0 to CsSzam Do
    begin
      If XM [I] = 0 then
      begin
        If zz < 319 then
          XC [I] := zz+Random (H-zz) else
            XC [I] := Random (320);
        YC [I] := Random (60)+70;
        If Byte (Ptr (Seg (DLKep), Ofs (DlKep)+846+XC [I]+Sor [YC [I]])^) <> 0 then
          XM [I] := 15;
        XE [I] := 30+Random (12);
      end else
      begin
        If XC [I] <= 319 then
          Csillam (XC [I], YC [I], SM [XM [I]], XE [I]);
        Dec (XM [I]);
      end;
    end;
    RW;HRajz;
  Until (Port [$60] = 1);
  Dispose (Hatter);
  DeinitMixer;
  DeInitModule;
End.