@echo off
rem Requires TEX_API_BASE / TEX_API_KEY in the environment. Log: %TEMP%\wow_tex_all.txt
set L=%TEMP%\wow_tex_all.txt
echo START > %L%
py "%~dp0gen_tex.py" roof_terracotta "warm orange terracotta clay roof tiles, rows of curved overlapping barrel tiles" >> %L% 2>&1
py "%~dp0gen_tex.py" plaster "smooth cream plaster stucco wall, subtle brush texture and soft stains, no windows, no bricks" >> %L% 2>&1
py "%~dp0gen_tex.py" brick "red brick wall, running bond pattern with light mortar lines, slightly varied brick colors" >> %L% 2>&1
py "%~dp0gen_tex.py" stone "light beige cut sandstone block wall, large rectangular ashlar blocks with thin joints" >> %L% 2>&1
py "%~dp0gen_tex.py" wood "vertical wooden planks, warm brown painted wood with grain" >> %L% 2>&1
py "%~dp0gen_tex.py" copper "weathered green copper verdigris metal sheet roof with vertical standing seams and patina streaks" >> %L% 2>&1
echo TEX_DONE >> %L%
