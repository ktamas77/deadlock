Function InstallSoundBlaster:Byte;Assembler;
{Alaphelyzetbe allitja az SB-t}
asm
     mov dx, 226h
     mov al, 1
     out dx, al    {226-os portra 1-et kuldunk}
     mov cx, 1000
  @1:loop @1       {Nehany millisec varakozas}
     xor al, al
     out dx, al    {226-os portra 0-at kuldunk}
     mov dx, 22Ah
     mov cx, 100
  @2:in al, dx     {Varunk nehany mmp-t, ezalatt $AA erteket kell kapnunk}
     cmp al, 0AAh
     je @3
     loop @2
     jmp @vege
  @3:mov dx, 22Ch  {22Ch portra --> $D1}
     mov al, 0D1h
     out dx, al
     xor al, al
  @vege:
end;

Procedure ReadyToSend;Assembler;
{Varakozik, amig nem lehet kikuldeni dolgot}
asm
     mov dx, 22Ch;
  @4:in al, dx
     rol al, 1
     jb @4
end;

Procedure ReadyToReceive;Assembler;
{Varakozik, amig nem lehet beszivni dolgot}
asm
     mov dx, 22Eh
  @5:in al, dx
     rol al, 1
     jnb @5
end;

Procedure SBByteOut;Assembler;
{Kikuld egy byte-ot az SB-re}
{bl = input!}
asm
  call ReadyToSend
  mov dx, 22Ch
  mov al, 10h
  out dx, al     {a $22C portra --> 10h}
  call ReadyToSend
  mov dx, 22Ch
  mov al, bl
  out dx, al     {a 22Ch portra --> kikuldendo byte}
end;

Function SBByteIn:Byte;Assembler;
{Besziv egy byte-ot az SB-rol}
asm
  call ReadyToSend
  mov dx, 22Ch
  mov al, 20h
  out dx, al              {A 22Ch portra --> $20}
  call ReadyToReceive
  mov dx, 22Ah
  in al, dx                {Az ahitott byte-ot leszedjuk aa 22Ah portrol}
end;

