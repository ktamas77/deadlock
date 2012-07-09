Program DL03;

Uses DU, DUTypes, DLTitle;

{$I DUMCGA.INC}
{$I FTRI.INC}

Const CsSzam = 200;

Var Pal: RGBMap;
    I  : Word;
    J  : Word;
    F  : Word;
    B  : Byte;
    FP, AP: Word;
    XC, YC: Array [0..CsSzam] of Integer;
    XM    : Array [0..CsSzam] of Integer;
    SM    : Array [0..15] of Byte;

Procedure Csillam (x,y,m: Integer);
Var I: Byte;
    B: Byte;
begin
  If m > 0 then
  For I := 0 to m-1 Do
  begin
    B := Hatter^[x+sor [y]-(m shr 1)+i];
    Inc (B, M);
    If B > 40 then B := 40;
    Hatter^[x+sor [y]-(m shr 1)+i] := B;

    B := Hatter^[x+sor [y-(m shr 1)+i]];
    Inc (B, M);
    If B > 40 then B := 40;
    Hatter^[x+sor [y-(m shr 1)+i]] := B;
  end;
 { If M >= 8 then
  begin
    Hatter^[x+sor [y-1]-1] := 64+M-6;
    Hatter^[x+sor [y-1]+1] := 64+M-6;
    Hatter^[x+sor [y+1]-1] := 64+M-6;
    Hatter^[x+sor [y+1]+1] := 64+M-6;
  end;}
end;

Begin
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
    Inc (F,2); {Ezt kell majd idoziteni}
    If F > 319 then F := 319;
    FP := 30;
    AP := 130;
    While (Byte (Ptr (Seg (DLKep), Ofs (DLKEp)+846+Sor [FP]+F)^) = 0) Do Inc (FP);
    While (Byte (Ptr (Seg (DLKep), Ofs (DLKEp)+846+Sor [AP]+F)^) = 0) Do Dec (AP);
    If FP < 130 then FTri (Hatter,159,99,F,FP,F,AP,20);
    {DeadLock}
    For I := 70 to 130 Do
    begin
      For J := 0 to F Do
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
    {Csillamok}
    For I := 0 to CsSzam Do
    begin
      If XM [I] = 0 then
      begin
        XC [I] := Random (F);
        YC [I] := Random (60)+70;
        If Hatter^ [XC [I]+Sor [YC [I]]] <> 0 then
        XM [I] := 14+Random (2);
      end else
      begin
        Csillam (XC [I], YC [I], SM [XM [I]]);
        Dec (XM [I]);
      end;
    end;
    RW;HRajz;
  Until (Port [$60] = 1);
  Dispose (Hatter);
End.