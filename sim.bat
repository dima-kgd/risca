@echo off
if /i "%1"=="uart" (
    set TB_NAME=risca_uart_tb
    set SRC=rtl/risca_cpu.v rtl/uart_tx.v tb/risca_uart_tb.v
) else (
    set TB_NAME=risca_tb
    set SRC=rtl/risca_cpu.v tb/risca_tb.v
)

echo Compiling %TB_NAME%...
iverilog -g2012 -o %TB_NAME%.vvp %SRC%
if %errorlevel% neq 0 (
    echo Compilation failed.
    exit /b %errorlevel%
)
echo Running simulation...
vvp %TB_NAME%.vvp
echo Opening GTKWave...
gtkwave %TB_NAME%.vcd
