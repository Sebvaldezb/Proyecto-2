; ============================================================================
; PROYECTO MODULO 2 - KEYGEN BASICO
; Lenguajes de Interfaz (SCC-1014)
;
; Alumno: Oscar Sebastian Valdez Barrios
; Matricula: 23490625
;
; Ensamblador: UASM64 (sintaxis compatible con MASM)
; Enlazador:   GoLink (aplicacion de consola x64)
; Dependencia: kernel32.dll
;
; FUNCIONAMIENTO:
;   1) Solicitar un nombre por consola (ReadConsoleA).
;   2) Validar que tenga entre 1 y 64 caracteres.
;   3) Sumar los valores de cada byte ASCII.
;   4) Aplicar XOR 0ABCDh como transformacion extra.
;   5) Convertir la llave de 64 bits a 16 digitos hexadecimales.
;   6) Mostrar el resultado mediante WriteConsoleA.
; ============================================================================

option casemap:none

extrn GetStdHandle:proc
extrn ReadConsoleA:proc
extrn WriteConsoleA:proc
extrn ExitProcess:proc

STD_INPUT_HANDLE  EQU -10
STD_OUTPUT_HANDLE EQU -11
MAX_NOMBRE        EQU 64
CAPACIDAD_ENTRADA EQU 128
LONGITUD_HEX      EQU 16

.data

    prompt          db 'Ingresa tu nombre de usuario: '
    PROMPT_LEN      EQU ($ - prompt)

    prefijoLlave    db 13, 10, 'Tu llave es: '
    PREFIJO_LEN     EQU ($ - prefijoLlave)

    saltoLinea      db 13, 10
    SALTO_LEN       EQU ($ - saltoLinea)

    errorVacio      db 13, 10, 'Error: nombre no valido (vacio).', 13, 10
    ERROR_VACIO_LEN EQU ($ - errorVacio)

    errorLargo      db 13, 10, 'Error: el nombre supera los 64 caracteres.', 13, 10
    ERROR_LARGO_LEN EQU ($ - errorLargo)

    errorLectura    db 13, 10, 'Error: no se pudo leer la consola.', 13, 10
    ERROR_LECT_LEN  EQU ($ - errorLectura)

    errorConsola    db 13, 10, 'Error: no se pudo acceder a la consola.', 13, 10
    ERROR_CONS_LEN  EQU ($ - errorConsola)

    hEntrada        dq 0
    hSalida         dq 0
    bytesLeidos     dd 0
    bytesEscritos   dd 0
    nombreLongitud  dd 0
    nombre          db CAPACIDAD_ENTRADA DUP (0)
    llave           dq 0
    hexadecimal     db LONGITUD_HEX DUP ('0')

.code

; ----------------------------------------------------------------------------
; MostrarTexto
; ENTRADA: RCX = direccion del texto, EDX = longitud en bytes.
; SALIDA:  EAX = BOOL devuelto por WriteConsoleA (0 = error).
; Convencion Windows x64: 32 bytes de shadow space y quinto argumento en
; [RSP+20h] antes de CALL, con RSP alineado a 16 bytes.
; ----------------------------------------------------------------------------
MostrarTexto PROC
    sub  rsp, 28h                 ; 32 bytes shadow + 8 para alineacion
    mov  r8d, edx                 ; argumento 3: cantidad de caracteres
    mov  rdx, rcx                 ; argumento 2: direccion del texto
    mov  rcx, qword ptr [hSalida] ; argumento 1: handle de salida
    lea  r9, bytesEscritos        ; argumento 4: caracteres escritos
    mov  qword ptr [rsp+20h], 0   ; argumento 5: reservado (NULL)
    call WriteConsoleA
    add  rsp, 28h
    ret
MostrarTexto ENDP

; ----------------------------------------------------------------------------
; LeerNombre
; Lee hasta 128 bytes, verifica nombre vacio y longitud de 64 caracteres.
; Los caracteres CR (13) y LF (10) no se incluyen en nombreLongitud.
; SALIDA: EAX = 1 correcto, 0 vacio, 2 excede 64, 3 fallo de lectura.
; No modifica los registros no volatiles de Windows x64.
; ----------------------------------------------------------------------------
LeerNombre PROC
    sub  rsp, 28h
    mov  rcx, qword ptr [hEntrada]
    lea  rdx, nombre
    mov  r8d, CAPACIDAD_ENTRADA
    lea  r9, bytesLeidos
    mov  qword ptr [rsp+20h], 0   ; pInputControl = NULL
    call ReadConsoleA
    add  rsp, 28h

    test eax, eax
    jz   lecturaFallida

    mov  r11d, dword ptr [bytesLeidos]
    test r11d, r11d
    jz   nombreVacio

    lea  r10, nombre
    xor  eax, eax                 ; EAX = longitud sin CR/LF

revisarCaracter:
    cmp  eax, r11d
    jae  finalizarRevision

    movzx edx, byte ptr [r10+rax]
    cmp  dl, 13                   ; retorno de carro
    je   finalizarRevision
    cmp  dl, 10                   ; salto de linea
    je   finalizarRevision
    cmp  dl, 0                    ; terminador nulo, si apareciera
    je   finalizarRevision

    inc  eax
    cmp  eax, MAX_NOMBRE
    ja   nombreDemasiadoLargo
    jmp  revisarCaracter

finalizarRevision:
    test eax, eax
    jz   nombreVacio
    mov  dword ptr [nombreLongitud], eax
    mov  eax, 1
    ret

nombreVacio:
    xor  eax, eax
    ret

nombreDemasiadoLargo:
    mov  eax, 2
    ret

lecturaFallida:
    mov  eax, 3
    ret
LeerNombre ENDP

; ----------------------------------------------------------------------------
; GenerarLlave
; Recorre exactamente nombreLongitud bytes, acumula ASCII en RAX (64 bits)
; y aplica la transformacion extra: llave = suma XOR 0ABCDh.
; SALIDA: [llave] contiene el valor resultante de 64 bits.
; ----------------------------------------------------------------------------
GenerarLlave PROC
    xor  rax, rax                 ; acumulador de 64 bits = 0
    mov  ecx, dword ptr [nombreLongitud]
    lea  r10, nombre

sumarASCII:
    test ecx, ecx
    jz   aplicarTransformacion
    movzx edx, byte ptr [r10]    ; convertir byte a entero sin signo
    add  rax, rdx                 ; suma de ASCII
    inc  r10                      ; siguiente caracter
    dec  ecx
    jmp  sumarASCII

aplicarTransformacion:
    xor  rax, 0ABCDh              ; bono: transformacion adicional
    mov  qword ptr [llave], rax
    ret
GenerarLlave ENDP

; ----------------------------------------------------------------------------
; ConvertirHex
; Convierte el entero de 64 bits de [llave] a 16 digitos HEX mayusculos.
; Extrae el nibble menos significativo y escribe de derecha a izquierda.
; No utiliza cadenas de formato, macros ni funciones de conversion externas.
; ----------------------------------------------------------------------------
ConvertirHex PROC
    mov  rax, qword ptr [llave]
    lea  r10, hexadecimal
    add  r10, LONGITUD_HEX - 1    ; ultimo caracter del buffer
    mov  ecx, LONGITUD_HEX

siguienteDigito:
    mov  edx, eax
    and  edx, 0Fh                ; extraer nibble de 4 bits
    cmp  dl, 9
    jbe  digitoNumerico

    add  dl, 'A' - 10             ; 10..15 -> A..F
    jmp  guardarDigito

digitoNumerico:
    add  dl, '0'                  ; 0..9 -> 0..9

guardarDigito:
    mov  byte ptr [r10], dl
    shr  rax, 4                   ; siguiente nibble
    dec  r10
    dec  ecx
    jnz  siguienteDigito
    ret
ConvertirHex ENDP

; ----------------------------------------------------------------------------
; main: orquesta todo el programa.
; ExitProcess recibe el codigo de salida en ECX (0 = exito).
; ----------------------------------------------------------------------------
main PROC
    sub  rsp, 28h                 ; alinear pila para llamadas externas

    mov  ecx, STD_INPUT_HANDLE
    call GetStdHandle
    cmp  rax, -1                  ; INVALID_HANDLE_VALUE
    je   salirSinConsola
    test rax, rax
    jz   salirSinConsola
    mov  qword ptr [hEntrada], rax

    mov  ecx, STD_OUTPUT_HANDLE
    call GetStdHandle
    cmp  rax, -1
    je   salirSinConsola
    test rax, rax
    jz   salirSinConsola
    mov  qword ptr [hSalida], rax

    lea  rcx, prompt
    mov  edx, PROMPT_LEN
    call MostrarTexto
    test eax, eax
    jz   errorIO

    call LeerNombre
    cmp  eax, 1
    je   entradaValida
    cmp  eax, 0
    je   mostrarErrorVacio
    cmp  eax, 2
    je   mostrarErrorLargo
    jmp  mostrarErrorLectura

entradaValida:
    call GenerarLlave
    call ConvertirHex

    lea  rcx, prefijoLlave
    mov  edx, PREFIJO_LEN
    call MostrarTexto
    test eax, eax
    jz   errorIO

    lea  rcx, hexadecimal
    mov  edx, LONGITUD_HEX
    call MostrarTexto
    test eax, eax
    jz   errorIO

    lea  rcx, saltoLinea
    mov  edx, SALTO_LEN
    call MostrarTexto
    test eax, eax
    jz   errorIO

    xor  ecx, ecx
    call ExitProcess

mostrarErrorVacio:
    lea  rcx, errorVacio
    mov  edx, ERROR_VACIO_LEN
    call MostrarTexto
    mov  ecx, 1
    call ExitProcess

mostrarErrorLargo:
    lea  rcx, errorLargo
    mov  edx, ERROR_LARGO_LEN
    call MostrarTexto
    mov  ecx, 2
    call ExitProcess

mostrarErrorLectura:
    lea  rcx, errorLectura
    mov  edx, ERROR_LECT_LEN
    call MostrarTexto
    mov  ecx, 3
    call ExitProcess

errorIO:
    lea  rcx, errorConsola
    mov  edx, ERROR_CONS_LEN
    call MostrarTexto             ; no se presupone que la salida funcione

salirSinConsola:
    mov  ecx, 3
    call ExitProcess
main ENDP

END main
