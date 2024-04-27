memcpy:
  push edx
  push ecx
nextmemcpy:
  sub ecx,4
  mov edx,eax
  add edx,ecx
  mov edi,[edx]
  mov edx,ebx
  add edx,ecx
  mov [edx],edi
%ifdef DEBUG
  ; read back what's written
  push eax
  mov eax,edx
  call eaxtty
  call space
  mov eax,[edx]
  call eaxtty
  call crlf
  pop eax
%endif
  jecxz endmemcpy
  jmp nextmemcpy
endmemcpy:
  pop ecx
  pop edx
  ret