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
for TABLE_NAME in $(mysql -u $user -p$pass $database -s -e 'SELECT DISTINCT TABLE_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = '\"ORG_ID\"' AND TABLE_SCHEMA='\"$database\"';')
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
    fi
    ((COUNT=COUNT+1))
  done

  # echo 'ALTER TABLE '$TABLE_NAME'' $MODIFY_COLUMN_STR ';'
  SQL_DROP_PRIMARY_KEY="DROP PRIMARY KEY"
  SQL_PRIMARY_KEY="ADD PRIMARY KEY (ID, ORG_ID)"
  SQL_ENGINE="ENGINE=ROCKSDB"
  SQL_PARTITION_BY_KEY="PARTITION BY KEY(ORG_ID)"
  SQL_PARTITION_NUMBER="PARTITIONS 64"
  SQL_COMMENT="COMMENT"
  STR_CF_NAME="_cfname"
  STR_CF="_cf"

  for i in {0..63}; 
  do 
    if [[ $i == 0 ]]; then
      SQL_COMMENT+=" ' p$i$STR_CF_NAME=${TABLE_NAME,,}_$i$STR_CF"
    else
      SQL_COMMENT+=";p$i$STR_CF_NAME=${TABLE_NAME,,}_$i$STR_CF"
    fi
  done
  
  # Concat end string of comment
  SQL_COMMENT+="'"

  echo "ALTER TABLE $TABLE_NAME $MODIFY_COLUMN_STR, $SQL_DROP_PRIMARY_KEY, $SQL_PRIMARY_KEY $SQL_COMMENT $SQL_PARTITION_BY_KEY $SQL_PARTITION_NUMBER;"
  mysql -u $user -p$pass $database -s -e "ALTER TABLE $TABLE_NAME $MODIFY_COLUMN_STR, $SQL_DROP_PRIMARY_KEY, $SQL_PRIMARY_KEY $SQL_COMMENT $SQL_PARTITION_BY_KEY $SQL_PARTITION_NUMBER;"

done

echo ''
echo 'Conversion done!'
echo ''
echo 'Optimizing tables...'
echo ''

mysqlcheck -u $user -p$pass $database --auto-repair --optimize

echo ''
