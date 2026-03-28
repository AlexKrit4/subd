# subd

Решение для задания по СУБД (Вариант 3) находится в файле [variant3_privatisation.sql](variant3_privatisation.sql).

Что внутри:
- `A)` одна таблица `privatization_all` со всеми атрибутами варианта.
- `B)` нормализованная схема из 4 связанных таблиц:
	- `buildings`
	- `flats`
	- `privatizations`
	- `residents`

В схеме `B` реализовано ключевое ограничение варианта:
один человек не может участвовать в приватизации более одной квартиры
(`UNIQUE INDEX` по `passport` при `sign_participation = true`).