# notes

- `CREATE TABLE <newDB>.<tableName> LIKE <oldDB>.<oldTableName>`       
   拷贝`<oldTableName>`的表结构到表`<tableName>`。
- `CREATE TABLE <newDB>.<tableName> AS SELECT * FROM <oldDB>.<oldTableName>`      
   拷贝`<oldTableName>`的表结构和数据到`<tableName>`。
