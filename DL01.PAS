Program DL01;

Uses DU, DUTypes, DLTitle;

{$I DUMCGA.INC}
{$I FTRI.INC}

Var Pal: RGBMap;
    I  : Word;
    J  : Word;
    F  : Word;
    B  : Byte;
    FP, AP: Word;

Begin
  MCGAINIT;
  GrOn;
  New (Hatter);
  Move (Ptr (Seg (DLKep), Ofs (DLKep)+40+32)^, Pal, 768);
  For I := 0 to 255 Do With Pal [I] Do begin R := R shr 2;G := G shr 2;B := B shr 2;end;
  SetRGBPal (Pal);
  {Move (Ptr (Seg (DLKep), Ofs (DLKEp)+846)^, VHatter, 64000);}
  F := 0;
  Repeat
    HCLS;
    Inc (F);
    If F > 319 then F := 319;
    FP := 30;
    AP := 130;
    While (Byte (Ptr (Seg (DLKep), Ofs (DLKEp)+846+Sor [FP]+F)^) = 0) Do Inc (FP);
    While (Byte (Ptr (Seg (DLKep), Ofs (DLKEp)+846+Sor [AP]+F)^) = 0) Do Dec (AP);
    If FP < 130 then FTri (Hatter,159,99,F,FP,F,AP,20);
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
    RW;HRajz;
  Until Port [$60] = 1;
  Dispose (Hatter);
End.