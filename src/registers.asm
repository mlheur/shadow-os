%define PAT1    0xfedcba09
%define PAT2    0x90abcdef
%define PAT3    0x87654321
%define PAT4    0x12345678
%define PAT5    0xffeeddcc
%define PAT6    0xbbaa0099

label_eax: db 'eax:',0
label_ebx: db 'ebx:',0
label_ecx: db 'ecx:',0
label_edx: db 'edx:',0
label_esp: db 'esp:',0
label_ebp: db 'ebp:',0
label_esi: db 'esi:',0
label_edi: db 'edi:',0
label_eip: db 'eip:',0
label_cs: db '_cs:',0
label_ss: db '_ss:',0
label_ds: db '_ds:',0
label_es: db '_es:',0
label_fs: db '_fs:',0
label_gs: db '_gs:',0
label_efl: db 'efl:',0
label_cr0: db 'cr0:',0
label_cr1: db 'cr1:',0
label_cr2: db 'cr2:',0
label_cr3: db 'cr3:',0

testregs:
  pushad
  mov eax,PAT1
  mov ebx,PAT2
  mov ecx,PAT3
  mov edx,PAT4
  mov esi,PAT5
  mov edi,PAT6
  call regsout
  popad
  ret

regsout:
  pushad
  mov eax,label_eax
  call sztty
  mov eax,[esp+28]
  call eaxtty
  call space
  mov eax,label_ebx
  call sztty
  mov eax,[esp+16]
  call eaxtty
  call space
  mov eax,label_ecx
  call sztty
  mov eax,[esp+24]
  call eaxtty
  call space
  mov eax,label_edx
  call sztty
  mov eax,[esp+20]
  call eaxtty
  call crlf
  mov eax,label_esp
  call sztty
  mov eax,[esp+12]
  call eaxtty
  call space
  mov eax,label_ebp
  call sztty
  mov eax,[esp+8]
  call eaxtty
  call space
  mov eax,label_esi
  call sztty
  mov eax,[esp+4]
  call eaxtty
  call space
  mov eax,label_edi
  call sztty
  mov eax,[esp+0]
  call eaxtty
  call crlf
  ;
  mov eax,label_eip
  call sztty
  ; https://stackoverflow.com/questions/4062403/how-to-check-the-eip-value-with-assembly-language
  call $+4
  pop eax
  call eaxtty
  call space
  ;
  mov eax,label_cs
  call sztty
  mov eax,cs
  call eaxtty
  call space
  ;
  mov eax,label_ss
  call sztty
  mov eax,ss
  call eaxtty
  call space
  ;
  mov eax,label_ds
  call sztty
  mov eax,ds
  call eaxtty
  call crlf
  ;
  mov eax,label_es
  call sztty
  mov eax,es
  call eaxtty
  call space
  ;
  mov eax,label_fs
  call sztty
  mov eax,fs
  call eaxtty
  call space
  ;
  mov eax,label_gs
  call sztty
  mov eax,gs
  call eaxtty
  call space
  ;
  mov eax,label_cr0
  call sztty
  mov eax,cr0
  call eaxtty
  call crlf
  ; Reading CR1 causes INT 0x00 that hasn't been set up yet.
  mov eax,label_efl
  call sztty
  pushfd
  pop eax
  call eaxtty
  call space
  ;
  mov eax,label_cr2
  call sztty
  mov eax,cr2
  call eaxtty
  call space
  ;
  mov eax,label_cr3
  call sztty
  mov eax,cr3
  call eaxtty
  call crlf
  ;
  popad
  ret