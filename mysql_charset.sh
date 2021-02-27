#!/bin/bash

while getopts u:p:d: flag
do
    case "${flag}" in
        u) user=${OPTARG};;
        p) pass=${OPTARG};;
        d) database=${OPTARG};;
    esac
done

echo $sql
for TABLE_NAME in $(mysql -u $user -p$pass $database -s -e 'SELECT DISTINCT TABLE_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='\"$database\"';')
do
  echo "Changing charset of table: $TABLE_NAME"
  COUNT=0
  MODIFY_COLUMN_STR=''
  set +m; shopt -s lastpipe
  mysql -u $user -p$pass $database -s -e 'SELECT column_name, column_type FROM information_schema.columns WHERE table_schema='\"$database\"' AND table_name='\"$TABLE_NAME\"';' | while read -r COLUMN_NAME COLUMN_TYPE;
  do
    if [[ $COLUMN_TYPE == 'varchar(24)' ]]; then
      # CONVERT CHARSET AND COLLATE
      if [[ $COUNT == 0 ]]; then
        if [[ $COLUMN_NAME == "ORG_ID" ]]; then
          MODIFY_COLUMN_STR+="MODIFY $COLUMN_NAME varchar(24) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL"
        else
          MODIFY_COLUMN_STR+="MODIFY $COLUMN_NAME varchar(24) CHARACTER SET latin1 COLLATE latin1_bin"
        fi
      else
        if [[ $COLUMN_NAME == "ORG_ID" ]]; then
          MODIFY_COLUMN_STR+=", MODIFY $COLUMN_NAME varchar(24) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL"
        else
          MODIFY_COLUMN_STR+=", MODIFY $COLUMN_NAME varchar(24) CHARACTER SET latin1 COLLATE latin1_bin"
        fi
      fi
      ((COUNT=COUNT+1))
    fi
  done


  echo "ALTER TABLE $TABLE_NAME $MODIFY_COLUMN_STR;">>sql_alter_charset.sql

done