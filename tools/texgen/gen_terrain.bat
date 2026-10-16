@echo off
rem Terrain textures (raw) -> tools/texgen/raw/t*.png ; needs TEX_API_BASE / TEX_API_KEY. Log %TEMP%\wow_tex_terrain.txt
set L=%TEMP%\wow_tex_terrain.txt
echo START > %L%
set S=ground surface seen straight from above, top-down, lush bright stylized fantasy MMORPG terrain texture like Mabinogi Eternity, soft hand-painted look, saturated but natural colors, no objects, no shadows of objects
start /b py "%~dp0gen_tex.py" t0_grass "short dense meadow grass, %S%, vivid fresh yellow-green with subtle lighter and darker clumps and tiny blade strokes" >> %L% 2>&1
start /b py "%~dp0gen_tex.py" t1_grass_dark "thick deep forest grass and clover, %S%, rich deep green with darker patches and a few fallen leaves" >> %L% 2>&1
start /b py "%~dp0gen_tex.py" t2_dirt "warm light brown packed dirt footpath with small pebbles and soft wheel ruts, %S%" >> %L% 2>&1
py "%~dp0gen_tex.py" t3_rock "light warm grey and beige stylized cliff rock surface with large chunky angular planes and soft cracks, %S%" >> %L% 2>&1
start /b py "%~dp0gen_tex.py" t4_sand "pale warm golden beach sand with tiny ripples and a few small shells, %S%" >> %L% 2>&1
start /b py "%~dp0gen_tex.py" t5_cobble "old town cobblestone pavement of rounded light grey and beige flagstones with thin grout lines, %S%" >> %L% 2>&1
py "%~dp0gen_tex.py" t6_farm "tilled dark brown farm soil in neat parallel furrows with a few green sprouts, %S%" >> %L% 2>&1
start /b py "%~dp0gen_tex.py" t7_flowers "flower meadow grass with scattered tiny white, yellow and lilac wildflowers, %S%" >> %L% 2>&1
py "%~dp0gen_tex.py" t8_moss "soft green moss and dark damp earth with small ferns and stones, %S%" >> %L% 2>&1
timeout /t 120 /nobreak >nul
echo TEX_DONE >> %L%
