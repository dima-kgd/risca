# Читаем все ваши Verilog файлы
read_verilog rtl/risca_cpu.v
read_verilog tb/risca_tb.v

# ... добавьте все ваши файлы

# Синтезируем для Gowin (архитектура GW1N-9K)
synth_gowin -top top -json output.json

# Выводим отчет о ресурсах
stat
