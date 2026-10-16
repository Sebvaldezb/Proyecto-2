# Proyecto Módulo 2 - Keygen Básico

Proyecto de **Lenguajes de Interfaz (SCC-1014)** realizado en ensamblador x86-64.

**Alumno:** Oscar Sebastian Valdez Barrios  
**Matrícula:** 23490625

## Descripción

El programa solicita un nombre de usuario y genera una llave a partir de sus caracteres. Para calcularla, suma los valores ASCII del nombre y aplica una operación `XOR` con la constante `0ABCDh`.

La llave se muestra en consola como un número hexadecimal de **16 dígitos**, en mayúsculas y con ceros a la izquierda.

## Generación de la llave

El procedimiento `GenerarLlave` recorre el nombre carácter por carácter. `R10` apunta al carácter actual y `RAX` almacena la suma.

```asm
movzx edx, byte ptr [r10]
add rax, rdx
```

Al terminar de sumar, se aplica la transformación:

```asm
xor rax, 0ABCDh
```

Por ejemplo, para **Ana**: `65 + 110 + 97 = 272` (`110h`). Después del XOR, la llave es `AADDh`.

## Conversión hexadecimal

El procedimiento `ConvertirHex` convierte la llave de 64 bits en una cadena de 16 caracteres.

Utiliza `AND` con `0Fh` para obtener los últimos 4 bits y `SHR RAX, 4` para continuar con el siguiente dígito. Los caracteres se guardan de derecha a izquierda, utilizando `0`–`9` y `A`–`F`.

## Entrada y salida en consola

Se utilizan las siguientes funciones de `kernel32.dll`:

- `GetStdHandle`: obtiene los manejadores de entrada y salida.
- `ReadConsoleA`: recibe el nombre de usuario.
- `WriteConsoleA`: muestra mensajes y la llave generada.
- `ExitProcess`: termina la ejecución.

El procedimiento `LeerNombre` valida que se introduzca un nombre de **1 a 64 caracteres**. Si está vacío o supera el límite, muestra un mensaje de error.

El código está organizado en procedimientos y **no utiliza macros**.

## Uso de inteligencia artificial

Se utilizó **ChatGPT** como apoyo para:

- Analizar los requisitos y criterios de evaluación del proyecto.
- Apoyar la elaboración y revisión del código ensamblador.
- Comprender la suma ASCII, la operación XOR y la conversión hexadecimal.
- Revisar la organización en procedimientos y el manejo de errores.
- Preparar la documentación y las pruebas del programa.

## Compilación

Ensamblar con **UASM64**:

```cmd
uasm64 -win64 -c -Fo"keygen_valdez_oscar.obj" "keygen_valdez_oscar.asm"
```

Enlazar con **GoLink** y `kernel32.dll`:

```cmd
GoLink /console /entry main /fo keygen_valdez_oscar.exe keygen_valdez_oscar.obj kernel32.dll
```

Ejecutar:

```cmd
keygen_valdez_oscar.exe
```

## Resultado esperado

Ejemplo de ejecución con el nombre **Ana**:

```text
Ingresa tu nombre de usuario: Ana

Tu llave es: 000000000000AADD
```

Si se presiona Enter sin escribir un nombre, el programa muestra:

```text
Error: nombre no valido (vacio).
```