ALTER TABLE db_version CHANGE COLUMN required_z1961_s1549_11964_01_mangos_conditions required_z1964_s1552_11968_01_mangos_creature_linking_template bit;

ALTER TABLE creature_linking_template ADD COLUMN search_range MEDIUMINT(8) UNSIGNED NOT NULL DEFAULT '0'  AFTER flag;
