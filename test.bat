@echo off
set TB_NAME=risca_tb
set SRC=risca.v risca_tb.v

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
