#!/bin/bash

####################################################################################################
#
#   Simple helper script to initialize CMaNGOS DB
#
####################################################################################################

# specific to this core
EXPENSION="Classic" #warning only 'Classic' or 'TBC' or 'WoTLK' elswere acid filename will be wrong
DATABASE_NAME_PREFIX="cm_$EXPENSION_"
DATABASE_UPDATE_FILE_PREFIX="z"

#internal use
SCRIPT_FILE="InstallFullDB.sh"
CONFIG_FILE="InstallFullDB.config"

# testing only
ADDITIONAL_PATH="sql/"
CORE_PATH="core"

#variables assigned and read from $CONFIG_FILE
MYSQL_HOST="localhost"
MYSQL_PORT="3306"
MYSQL_USERNAME="cmangos"
MYSQL_PASSWORD="cmangos"
MYSQL_USERIP="localhost"
ROOTUSERNAME=""
ROOTPASSWORD=""
ROOTSUCCESS=false
WORLD_DB_NAME=$DATABASE_NAME_PREFIX"world"
REALM_DB_NAME=$DATABASE_NAME_PREFIX"realm"
CHAR_DB_NAME=$DATABASE_NAME_PREFIX"characters"
MYSQL_EXE=""
DEV_UPDATES="NO"
FORCE_WAIT="YES"

#internal variables
SOURCE_REALMDB_VER="0"
SOURCE_CHARACTERDB_VER="0"
SOURCE_WORLDDB_VER="0"
DB_RELEASE_TITLE=""
DB_RELEASE_NEXT_MILESTONE=""
DB_WORLDDB_VERSION=""
DB_REALMDB_VERSION=""
DB_CHARDB_VERSION=""
OLDIFS="$IFS"

## All SQLs used in this script
function set_sql_queries
{
  # create databases
  SQL_CREATE_WORLD_DB="CREATE DATABASE \`$WORLD_DB_NAME\` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
  SQL_CREATE_CHAR_DB="CREATE DATABASE \`$CHAR_DB_NAME\` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
  SQL_CREATE_REALM_DB="CREATE DATABASE \`$REALM_DB_NAME\` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"

  # create database user and grant privileges
  SQL_CREATE_DATABASE_USER="CREATE USER IF NOT EXISTS '$MYSQL_USERNAME'@'$MYSQL_USERIP' IDENTIFIED BY '$MYSQL_PASSWORD';"
  SQL_GRANT_TO_WORLD_DATABASE="GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, LOCK TABLES, CREATE TEMPORARY TABLES, EXECUTE, ALTER ROUTINE, CREATE ROUTINE ON \`$WORLD_DB_NAME\`.* TO '$MYSQL_USERNAME'@'$MYSQL_USERIP';"
  SQL_GRANT_TO_CHAR_DATABASE=("GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, LOCK TABLES, CREATE TEMPORARY TABLES ON \`$CHAR_DB_NAME\`.* TO '$MYSQL_USERNAME'@'$MYSQL_USERIP';")
  SQL_GRANT_TO_REALM_DATABASE=("GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, LOCK TABLES, CREATE TEMPORARY TABLES ON \`$REALM_DB_NAME\`.* TO '$MYSQL_USERNAME'@'$MYSQL_USERIP';")

  # delete user
  SQL_DROP_DATABASE_USER="DROP USER IF EXISTS '$MYSQL_USERNAME'@'$MYSQL_USERIP';"

  # deletes databases
  SQL_DROP_WORLD_DB="DROP DATABASE IF EXISTS \`$WORLD_DB_NAME\`;"
  SQL_DROP_CHAR_DB="DROP DATABASE IF EXISTS \`$CHAR_DB_NAME\`;"
  SQL_DROP_REALM_DB="DROP DATABASE IF EXISTS \`$REALM_DB_NAME\`;"

  # query realm list 
  SQL_QUERY_REALM_LIST="SELECT * FROM realmlist;"
  SQL_UPDATE_REALM_LIST="UPDATE realmlist SET " # field=value WHERE id=choosenid
  SQL_INSERT_REALM_LIST="INSERT INTO realmlist (\`id\`,\`name\`,\`address\`,\`port\`) VALUES "
  SQL_DELETE_REALM_ID="DELETE FROM realmlist WHERE id="

  # base files from core
  SQL_FILE_BASE_WORLD="core/sql/base/mangos.sql"
  SQL_FILE_BASE_CHAR="core/sql/base/characters.sql"
  SQL_FILE_BASE_REALM="core/sql/base/realmd.sql"
}

function save_settings
{
  declare -a allsettings
  
  allsettings+=("####################################################################################################")
  allsettings+=("# This is the config file for the '$SCRIPT_FILE' script")
  allsettings+=("#")
  allsettings+=("# You need to insert")
  allsettings+=("#   MYSQL_HOST:      Host on which the database resides")
  allsettings+=("#   MYSQL_PORT:      Port on which the database is running")
  allsettings+=("#   MYSQL_USERNAME:  Your a valid mysql username")
  allsettings+=("#   MYSQL_PASSWORD:  Your corresponding mysql password")
  allsettings+=("#   MYSQL_EXE:       Your mysql command (usually mysql)")
  allsettings+=("#   WORLD_DB_NAME:   Your content database")
  allsettings+=("#   REALM_DB_NAME:   Your realm database")
  allsettings+=("#   CHAR_DB_NAME :   Your characters database")
  allsettings+=("#")
  allsettings+=("####################################################################################################")
  allsettings+=("")
  allsettings+=("## Define the host on which the mangos database resides (typically localhost)")
  allsettings+=("MYSQL_HOST=\"$MYSQL_HOST\"")
  allsettings+=("")
  allsettings+=("## Define the port on which the mangos database is running (typically 3306)")
  allsettings+=("MYSQL_PORT=\"$MYSQL_PORT\"")
  allsettings+=("")
  allsettings+=("## Define your username")
  allsettings+=("MYSQL_USERNAME=\"$MYSQL_USERNAME\"")
  allsettings+=("")
  allsettings+=("## Define your password (It is suggested to restrict read access to this file!)")
  allsettings+=("MYSQL_PASSWORD=\"$MYSQL_PASSWORD\"")
  allsettings+=("")
  allsettings+=("## Define your server ip (core server ip, keep localhost if database and core are on same server")
  allsettings+=("MYSQL_USERIP=\"$MYSQL_USERIP\"")
  allsettings+=("")
  allsettings+=("## Define the databases names (let them empty for default name '"$DATABASE_NAME_PREFIX"dbtype')")
  allsettings+=("WORLD_DB_NAME=\"$WORLD_DB_NAME\"")
  allsettings+=("REALM_DB_NAME=\"$REALM_DB_NAME\"")
  allsettings+=("CHAR_DB_NAME=\"$CHAR_DB_NAME\"")
  allsettings+=("")
  allsettings+=("## Define your mysql programm if this differs")
  allsettings+=("MYSQL_EXE=\"mysql\"")
  allsettings+=("")
  allsettings+=("## Define if you want to wait a bit before applying the full database")
  allsettings+=("FORCE_WAIT=\"YES\"")
  allsettings+=("")
  allsettings+=("## Define if the 'dev' directory for processing development SQL files needs to be used")
  allsettings+=("##   Set the variable to "YES" to use the dev directory")
  allsettings+=("DEV_UPDATES=\"NO\"")
  allsettings+=("")
  allsettings+=("# Enjoy using the tool")

  # save to file
  for j in "${allsettings[@]}"
  do
  echo $j 
  done > $CONFIG_FILE
}

function wait_key
{
  read -n1 -r -p "Press space to continue..." key
}

# execute sql command and print error if any
# execute_sql_command "database" "sql" "message"(if empty no message is shown) return true if success
function execute_sql_command()
{
  if [ ! -z "$3" ]; then echo -n "$3 ... "; fi
  export MYSQL_PWD="$MYSQL_PASSWORD"
  MYSQL_ERROR=$("$MYSQL_EXE" -u"$MYSQL_USERNAME" -h"$MYSQL_HOST" -P"$MYSQL_PORT" -s -N -D "$1" -e"$2" 2>&1)
  if [[ $? != 0 ]]; then
    if [ ! -z "$3" ]; then
      echo "FAILED!"
      echo ">>> $MYSQL_ERROR";
    fi
    false
    return
  else
    if [ ! -z "$3" ]; then echo "SUCCESS"; fi
  fi
  true
}

# execute file that contain sql and print error if any message is provided
# execute_sql_file "database" "filename" "message"(if empty no message is shown) return true if success else MYSQL_ERROR contain the error
function execute_sql_file()
{
  if [ ! -z "$3" ]; then echo -n "$3 ... "; fi
  export MYSQL_PWD="$MYSQL_PASSWORD"
  MYSQL_ERROR=$("$MYSQL_EXE" -u"$MYSQL_USERNAME" -h"$MYSQL_HOST" -P"$MYSQL_PORT" -s -N -D $1 < $2 2>&1)
  if [[ $? != 0 ]]; then
    if [ ! -z "$3" ]; then
      echo "FAILED!"
      echo ">>> $MYSQL_ERROR";
    fi
    false
    return
  else
    if [ ! -z "$3" ]; then echo "SUCCESS"; fi
  fi
  true
}

# Core updates
function update_core_sql
{
  echo -n "  Trying to apply last core updates ... "
  local LAST_CORE_REV=0
  local UPD_PROCESSED=0
  unset CORE_REVS
  CORE_REVS+=($(grep -r "^.*required_[a-z]*[0-9]*.* DEFAULT NULL" sql/Full_DB/* | sed 's/.*required_[a-z]*\([0-9]*\)_\([0-9]*\).*/\1\2/'))
  #printf '%s\n' "${CORE_REVS[@]}"
  CORE_REVS+=($(grep -ri ".*alter table.*required_$DATABASE_UPDATE_FILE_PREFIX" sql/Updates/* | sed "s/.*required_[a-z]*\([0-9]*\)_\([0-9]*\).*/\1\2/"))
  #printf '%s\n' "${CORE_REVS[@]}"
  if [ "${#CORE_REVS[@]}" -gt 0 ]; then
    for rev in "${CORE_REVS[@]}"
    do
      if [ $rev -gt $LAST_CORE_REV ]; then
        LAST_CORE_REV=$rev
      fi
    done
  fi
  
  if [ "$LAST_CORE_REV" -eq 0 ]
  then
    echo "FAILED!"
    echo ">>> ERROR: cannot get last core revision in DB"
    false
    return
  fi
  local wdbrev=$(echo "$SOURCE_WORLDDB_VER" |sed 's/[a-z]*\([0-9]*\)_\([0-9]*\).*/\1\2/g')
  #echo "    $EXPENSION DB core rev($LAST_CORE_REV), expected core rev($wdbrev)"
  for f in "core/sql/updates/mangos/"*_mangos_*.sql
  do
    CUR_REV=$(basename "$f" | sed "s/^$DATABASE_UPDATE_FILE_PREFIX\([0-9]*\)_\([0-9]*\).*/\1\2/")
    if [ "$CUR_REV" -gt "$LAST_CORE_REV" ]; then
      # found a newer core update file
      if ! execute_sql_file "$WORLD_DB_NAME" "$f"; then
        echo "FAILED!"
        echo ">>> $MYSQL_ERROR"
        false
        return
      fi
      ((UPD_PROCESSED++))
    fi
  done
  echo "SUCCESS"
  if [ $UPD_PROCESSED -le 1 ];then
    echo "    No core updates needed"
  else
    echo "    $UPD_PROCESSED successfully added."
  fi
  true
}

# Apply dbc folder
function apply_full_dbc_data
{
  echo -n "  Trying to apply dbc datas ... "
  for f in "core/sql/base/dbc/original_data/"*.sql
  do
    if ! execute_sql_file "$WORLD_DB_NAME" "$f"; then
      echo "FAILED!"
      echo ">>> $MYSQL_ERROR"
      false
      return
    fi
  done
  echo "SUCCESS"

    # Apply dbc changes (specific fixes to known wrong/missing data)
  echo -n "  Trying to apply CMaNGOS fixes to dbc datas ... "
  for f in "core/sql/base/dbc/cmangos_fixes/"*.sql
  do
    if ! execute_sql_file "$WORLD_DB_NAME" "$f"; then
      echo "FAILED!"
      echo ">>> $MYSQL_ERROR"
      false
      return
    fi
  done
  echo "SUCCESS"
  true
}


# Apply scriptdev2.sql
function apply_full_scriptdev2_data
{
  if ! execute_sql_file "$WORLD_DB_NAME" "core/sql/scriptdev2/scriptdev2.sql" "  Trying to apply ScripDev2 datas"; then
    false
    return
  fi
  true
}

function update_content_db
{
  echo "It is not possible yet to update the content DB as there is no revision for it so only core updates will be applied!"
  echo "Choose to recreate it fully if you want latest content updates"

  if ! update_core_sql; then
    false
    return
  fi
  true
}

# Apply dev custom changes
function apply_dev_content
{
  echo -n "  Trying to apply development updates ... "
  for UPDATEFILE in "dev/*.sql"
  do
    if [ -e "$UPDATEFILE" ]; then
      for UPDATE in "dev/*.sql"
      do
        if ! execute_sql_file "$WORLD_DB_NAME" "$UPDATE"; then
          echo "FAILED!"
          echo ">>> $MYSQL_ERROR"
          false
          return
        fi
      done
    fi
    break
  done

  # processing individual folder in dev folder
  for UPDATEFILE in "dev/*/*.sql"
  do
    if [ -e "$UPDATEFILE" ]; then
        for UPDATE in "dev/*/*.sql"
        do
            if ! execute_sql_file "$WORLD_DB_NAME" "$UPDATE"; then
            echo "FAILED!"
            echo ">>> $MYSQL_ERROR"
            false
            return
          fi
        done
    fi
    break
  done
  echo "SUCCESS"
}

function apply_full_content_db
{
  #export MYSQL_PWD="$MYSQL_PASSWORD"
  #local MYSQL_COMMAND="$MYSQL_EXE -u$MYSQL_USERNAME -h$MYSQL_HOST -P$MYSQL_PORT -s -N -D$WORLD_DB_NAME"
  ## Full Database
  echo -n "  Processing $EXPENSION database $DB_RELEASE_TITLE ... "
  if ! execute_sql_file "$WORLD_DB_NAME" "sql/Full_DB/$FULL_CONTENT_FILE" "  Processing $EXPENSION database $DB_RELEASE_TITLE"; then
    false
    return
  fi

  ## Updates
  echo -n "  Processing $DB_RELEASE_TITLE updates ... "
  COUNT=0
  for UPDATE in "sql/Updates/"[0-9]*.sql
  do
    if [ -e "$UPDATE" ]; then
      if ! execute_sql_file "$WORLD_DB_NAME" "$UPDATE" "  Processing $DB_RELEASE_TITLE updates"; then
        false
        return
      fi
      ((COUNT++))
    fi
  done
  echo "$COUNT successfully added."

  # apply core updates
  if !update_core_sql; then
    false
    return
  fi

  # Apply dbc folder
  if !apply_full_dbc_data; then
    false
    return
  fi

  # Apply scriptdev2.sql
  if !apply_full_scriptdev2_data; then
    false
    return
  fi

  #               ACID Full file
  local explowcase=$(echo ${EXPENSION,,})
  if ! execute_sql_file "$WORLD_DB_NAME" "sql/ACID/acid_$explowcase.sql" "  Trying to apply ACID file"; then
    false
    return
  fi
  echo "SUCCESS"

  
  #    DEVELOPERS UPDATES
  if [ "$DEV_UPDATES" == "YES" ]; then
    if !apply_dev_content; then
      false
      return
    fi
  fi

  true
}

print_underline()
{
  echo $1
  echo "${1//?/${2:--}}"
}
function try_connect_to_db
{
  #echo -n "> Checking mysql database accessibility..."
  ERRORS=$($MYSQL_COMMAND -s -e ";" 2>&1)
  if [[ $? != 0 ]]
  then
    #echo "FAILED!"
    echo ">>> $ERRORS"
    false
    return
  #else
    #echo "SUCCESS"
  fi
  true
}

# Get current db version
# get_current_db_version "database name" "table name"
# result will be in CURRENT_DB_VERSION
function get_current_db_version()
{
  CURRENT_DB_VERSION=""
  sql="SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='$1' AND TABLE_NAME='$2';"
  #echo "$sql"
  while read -a row
  do
    #echo "${row[0]}"
    case "${row[0]}" in
      *required_*)
        CURRENT_DB_VERSION=$(echo "${row[0]//[$'\n\r']}") # remove eventual carriage return
        CURRENT_DB_VERSION=$(echo -n "${CURRENT_DB_VERSION//required_}") # remove "required_"
        return;;
     esac
  done < <("$MYSQL_EXE" -u"$MYSQL_USERNAME" -h"$MYSQL_HOST" -P"$MYSQL_PORT" -s -N -e"$sql")
  CURRENT_DB_VERSION="Revision not found in db"
}

# Check if db version of provided database is the required one
# check_db_version "database name" "table name" "required revison"
# return true or false. Current db version will be in CURRENT_DB_VERSION
function check_db_version ()
{
  echo -n "Checking '$1' database version..."
  get_current_db_version $1 $2
  if [[ $CURRENT_DB_VERSION == $3 ]]
  then
    echo "success"
    true
    return
  fi
  echo "failed!"
  echo -e "\tYour current version : \t\"$CURRENT_DB_VERSION\""
  echo -e "\tRequired db version  : \t\"$3\""
  false
}

# check if we can access dbs and retrieve their version
# check_dbs_accessibility bool (if parameter is true the result is displayed)
function check_dbs_accessibility()
{
  local showstatus="${1:false}"
  if ! try_connect_to_db ; then
    false
    return
  fi
  local result=0
  if $showstatus; then
    echo
    echo -n "> Checking $WORLD_DB_NAME accessibility..."
  fi
  ERRORS=$($MYSQL_COMMAND -D$WORLD_DB_NAME -s -e ";" 2>&1)
  if [[ $? != 0 ]];  then
    if $showstatus; then echo "FAILED!"; fi
    echo ">>> $ERRORS"
    DB_WORLDDB_VERSION=""
    result+=1
  else
    if $showstatus; then echo "SUCCESS"; fi
    get_current_db_version "$WORLD_DB_NAME" "db_version"
    DB_WORLDDB_VERSION="$CURRENT_DB_VERSION"
  fi
  if $showstatus; then
    echo
    echo -n "> Checking $REALM_DB_NAME accessibility..."
  fi
  ERRORS=$($MYSQL_COMMAND -D$REALM_DB_NAME -s -e ";" 2>&1)
  if [[ $? != 0 ]]
  then
    if $showstatus; then echo "FAILED!"; fi
    echo ">>> $ERRORS"
    DB_REALMDB_VERSION=""
    result+=1
  else
    if $showstatus; then echo "SUCCESS"; fi
    get_current_db_version "$REALM_DB_NAME" "realmd_db_version"
    DB_REALMDB_VERSION="$CURRENT_DB_VERSION"
  fi
  if $showstatus; then
    echo
    echo -n "> Checking $CHAR_DB_NAME accessibility..."
  fi
  ERRORS=$($MYSQL_COMMAND -D$CHAR_DB_NAME -s -e ";" 2>&1)
  if [[ $? != 0 ]]
  then
    if $showstatus; then echo "FAILED!"; fi
    echo ">>> $ERRORS"
    DB_CHARDB_VERSION=""
    result+=1
  else
    if $showstatus; then echo "SUCCESS"; fi
    get_current_db_version "$CHAR_DB_NAME" "character_db_version"
    DB_CHARDB_VERSION="$CURRENT_DB_VERSION"
  fi
  echo
  if [ $result -gt 0 ]
  then
    false
  else
    true
  fi
}

function check_settings
{
  CHANGESETTING="y"
  while [[ "$CHANGESETTING" =~ ^[Yy]$ ]]
  do
    clear
    show_mysql_settings
    echo
    if check_dbs_accessibility true
    then
      echo "> Connection established to your remote database"
    else
      echo ">>> Unable to establish a connection to all of the databases"
    fi
    echo
    read -e -p "Do you want to change something [y/N]? " CHANGESETTING
    if [[ "$CHANGESETTING" =~ ^[Yy]$ ]]
    then
      change_mysql_settings
      save_settings
      set_sql_queries
      export MYSQL_PWD="$MYSQL_PASSWORD"
      MYSQL_COMMAND="$MYSQL_EXE -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USERNAME"
    fi
  done
}

function show_mysql_settings
{
  echo -e "Database host...........= $MYSQL_HOST"
  echo -e "Database port...........= $MYSQL_PORT"
  echo -e "MySQL user..............= $MYSQL_USERNAME@$MYSQL_USERIP (password is defined in $CONFIG_FILE)"
  echo -e "World database name.....= $WORLD_DB_NAME"
  echo -e "Realm database name.....= $REALM_DB_NAME"
  echo -e "Character database name.= $CHAR_DB_NAME"
}

function show_dbs_versions
{
  if check_dbs_accessibility
  then
    echo "> All database already exist and are accessible"
  else
    echo "> Some databases are not accessible its either they dont exist or the mysql user have not right to access them"
    echo ">> $WORLD_DB_NAME version is '$DB_WORLDDB_VERSION'"
    echo ">> $CHAR_DB_NAME version is '$DB_CHARDB_VERSION'"
    echo ">> $REALM_DB_NAME version is '$DB_REALMDB_VERSION'"
  fi
}

function change_mysql_settings
{
  read -e -p    "Enter MySQL host................: " -i $MYSQL_HOST MYSQL_HOST
  read -e -p    "Enter MySQL port................: " -i $MYSQL_PORT MYSQL_PORT
  read -e -p    "Enter MySQL user................: " -i $MYSQL_USERNAME MYSQL_USERNAME
  read -e -s -p "Enter MySQL password............: " MYSQL_PASSWORD
  echo "***********"
  read -e -p    "Enter MySQL client IP...........: " -i $MYSQL_USERIP MYSQL_USERIP
  read -e -p    "Enter world database name.......: " -i $WORLD_DB_NAME WORLD_DB_NAME
  read -e -p    "Enter characters database name..: " -i $REALM_DB_NAME REALM_DB_NAME
  read -e -p    "Enter realm database name.......: " -i $CHAR_DB_NAME CHAR_DB_NAME
  save_settings
}


function update_realm_db
{
  local UPD_PROCESSED=0
  echo -n "  Trying to apply last realm db updates ... "
  #echo "$DB_REALMDB_VERSION"
  local CUR_DB_REV=$(echo "$DB_REALMDB_VERSION" | sed "s/^$DATABASE_UPDATE_FILE_PREFIX\([0-9]*\)_\([0-9]*\).*/\1\2/")
  #echo "CUR_DB_REV=$CUR_DB_REV"
  for f in "core/sql/updates/realmd/"*_realmd_*.sql
  do
    CUR_REV=$(basename "$f" | sed "s/^$DATABASE_UPDATE_FILE_PREFIX\([0-9]*\)_\([0-9]*\).*/\1\2/")
    #echo "CUR_REV=$CUR_REV"
    if [ $CUR_REV -gt $CUR_DB_REV ]; then
      # found a newer core update file
      if ! execute_sql_file "$REALM_DB_NAME" "$f"; then
        echo "FAILED!"
        echo ">>> $MYSQL_ERROR"
        false
        return
      fi
      ((UPD_PROCESSED++))
    fi
  done
  echo "SUCCESS"
  if [ $UPD_PROCESSED -le 1 ];then
    echo "    No realmd db updates needed"
  else
    echo "    $UPD_PROCESSED successfully added."
  fi
  true
}

function update_characters_db
{
  local UPD_PROCESSED=0
  echo -n "  Trying to apply last character db updates ... "
  #echo "$DB_CHARDB_VERSION"
  local CUR_DB_REV=$(echo "$DB_CHARDB_VERSION" | sed "s/^$DATABASE_UPDATE_FILE_PREFIX\([0-9]*\)_\([0-9]*\).*/\1\2/")
  #echo "CUR_DB_REV=$CUR_DB_REV"
  for f in "core/sql/updates/characters/"*_characters_*.sql
  do
    CUR_REV=$(basename "$f" | sed "s/^$DATABASE_UPDATE_FILE_PREFIX\([0-9]*\)_\([0-9]*\).*/\1\2/")
    #echo "CUR_REV=$CUR_REV"
    if [ $CUR_REV -gt $CUR_DB_REV ]; then
      # found a newer core update file
      if ! execute_sql_file "$CHAR_DB_NAME" "$f"; then
        echo "FAILED!"
        echo ">>> $MYSQL_ERROR"
        false
        return
      fi
      ((UPD_PROCESSED++))
    fi
  done
  echo "SUCCESS"
  if [ $UPD_PROCESSED -le 1 ];then
    echo "    No characters db updates needed"
  else
    echo "    $UPD_PROCESSED successfully added."
  fi
  true
}


function update_databases
{
  if ! update_content_db; then
    false
    return
  fi

  if ! update_realm_db; then
    false
    return
  fi

  if ! update_characters_db; then
    false
    return
  fi
  true
}

function set_try_root_connect_to_db
{
  if [ "$1" = true ]; then
    read -e -p    "Enter MySQL root user...........: " ROOTUSERNAME
    read -e -s -p "Enter MySQL root password.......: " ROOTPASSWORD
    echo "**********"
    echo -n "> Checking mysql database accessibility with root access..."
  fi
  export MYSQL_PWD="$ROOTPASSWORD"
  ERRORS=$("$MYSQL_EXE" -u"$ROOTUSERNAME" -h"$MYSQL_HOST" -P"$MYSQL_PORT" -s -N -e";" 2>&1)
  if [[ $? != 0 ]]
  then
    if [ "$1" = true ]; then echo "FAILED!"; fi
    echo "> $ERRORS"
    export MYSQL_PWD="$MYSQL_PASSWORD"
    ROOTSUCCESS=false
    false
    return
  else
    if [ "$1" = true ]; then echo "SUCCESS"; fi
  fi
  export MYSQL_PWD="$MYSQL_PASSWORD"
  ROOTSUCCESS=true
  true
}

# retrieve db title and next milestones needed for script
function get_source_title_milestone
{
  installdbscript_file="sql/InstallFullDB.sh"
  while IFS= read -r line
  do
    case "$line" in
      # try to read character db version
      FULLDB_FILE=*)
      IFS='=' read -r -a sarray <<< "$line"
      FULL_CONTENT_FILE=${sarray[1]//[$'\"\r\n']};;
      
      # try to read realmd db version
      DB_TITLE=*)
      IFS='=' read -r -a sarray <<< "$line"
      DB_RELEASE_TITLE=${sarray[1]//[$'\"\r\n']};;
  
      # try to read character db version
      NEXT_MILESTONES=*)
      IFS='=' read -r -a sarray <<< "$line"
      DB_RELEASE_NEXT_MILESTONE=${sarray[1]//[$'\"\r\n']}
      break;; # we can break here as milestone is the last interesting entry in the file
    esac
  done <"$installdbscript_file"
  IFS="$OLDIFS"
  
  if [ -z "$DB_RELEASE_TITLE" ] || [ -z "$DB_RELEASE_NEXT_MILESTONE" ]
  then
    echo "Error retrieving db title or db milestones!"
    exit 1
  fi

}

# retrieve current revision from source file
function get_current_source_db_version
{
  revision_file="core/src/shared/revision_sql.h"
  while IFS= read -r line
  do
    case "$line" in 
      # try to read realmd db revision
      *REVISION_DB_REALMD*)
      sarray=($line)
      SOURCE_REALMDB_VER=${sarray[2]//[$'\"\r\n']}
      SOURCE_REALMDB_VER=${SOURCE_REALMDB_VER//required_};;
  
      # try to read character db revision
      *REVISION_DB_CHARACTERS*)
      sarray=($line)
      SOURCE_CHARACTERDB_VER=${sarray[2]//[$'\"\r\n']}
      SOURCE_CHARACTERDB_VER=${SOURCE_CHARACTERDB_VER//required_};;
  
      # try to read world db revision
      *REVISION_DB_MANGOS*)
      sarray=($line)
      SOURCE_WORLDDB_VER=${sarray[2]//[$'\"\r\n']}
      SOURCE_WORLDDB_VER=${SOURCE_WORLDDB_VER//required_};;
    esac
  done <"$revision_file"
  IFS="$OLDIFS"
}

function create_db_user_and_set_privileges
{
  echo -n "> Creating $MYSQL_USERNAME user in database ... "
  sqlcreate+=("$SQL_DROP_DATABASE_USER")
  sqlcreate+=("$SQL_CREATE_DATABASE_USER")
  sqlcreate+=("$SQL_GRANT_TO_WORLD_DATABASE")
  sqlcreate+=("$SQL_GRANT_TO_CHAR_DATABASE")
  sqlcreate+=("$SQL_GRANT_TO_REALM_DATABASE")
  export MYSQL_PWD="$ROOTPASSWORD"
  for sql in "${sqlcreate[@]}"
  do
    ERRORS=$("$MYSQL_EXE" -u"$ROOTUSERNAME" -h"$MYSQL_HOST" -P"$MYSQL_PORT" -s -N -e"$sql" 2>&1)
    if [[ $? != 0 ]]; then
      echo "FAILED!"
      echo ">>> $ERRORS"
      false
      return
    fi
  done
  echo "SUCCESS"
  unset sqlcreate
  export MYSQL_PWD="$MYSQL_PASSWORD"
  true
}

function create_and_fill_world_db
{
  echo -n "> Creating $WORLD_DB_NAME database ... "
  unset sqlcreate
  sqlcreate+=("$SQL_DROP_WORLD_DB")
  sqlcreate+=("$SQL_CREATE_WORLD_DB")
  export MYSQL_PWD="$ROOTPASSWORD"
  for sql in "${sqlcreate[@]}"
  do
    ERRORS=$("$MYSQL_EXE" -u"$ROOTUSERNAME" -h"$MYSQL_HOST" -P"$MYSQL_PORT" -s -N -e"$sql" 2>&1)
    if [[ $? != 0 ]]; then
      echo "FAILED!"
      echo ">>> $ERRORS"
      export MYSQL_PWD="$MYSQL_PASSWORD"
      false
      return
    fi
  done
  
  if ! execute_sql_file "$WORLD_DB_NAME" "$SQL_FILE_BASE_WORLD"; then
    echo "FAILED!"
    false
    return
  fi
  echo "SUCCESS"

  if ! apply_full_content_db; then
    false
    return
  fi
  true
}

function create_and_fill_char_db
{
  echo -n "> Creating $CHAR_DB_NAME database ... "
  unset sqlcreate
  sqlcreate+=("$SQL_DROP_CHAR_DB")
  sqlcreate+=("$SQL_CREATE_CHAR_DB")
  export MYSQL_PWD="$ROOTPASSWORD"
  for sql in "${sqlcreate[@]}"
  do
    ERRORS=$("$MYSQL_EXE" -u"$ROOTUSERNAME" -h"$MYSQL_HOST" -P"$MYSQL_PORT" -s -N -e"$sql" 2>&1)
    if [[ $? != 0 ]]; then
      echo "FAILED!"
      echo ">>> $ERRORS"
      export MYSQL_PWD="$MYSQL_PASSWORD"
      false
      return
    fi
  done
  
  if ! execute_sql_file "$CHAR_DB_NAME" "$SQL_FILE_BASE_CHAR"; then
    echo "FAILED!"
    false
    return
  fi
  echo "SUCCESS"
  true
}

function create_and_fill_realm_db
{
  echo -n "> Creating $REALM_DB_NAME database..."
  unset sqlcreate
  sqlcreate+=("$SQL_DROP_REALM_DB")
  sqlcreate+=("$SQL_CREATE_REALM_DB")
  export MYSQL_PWD="$ROOTPASSWORD"
  for sql in "${sqlcreate[@]}"
  do
    ERRORS=$("$MYSQL_EXE" -u"$ROOTUSERNAME" -h"$MYSQL_HOST" -P"$MYSQL_PORT" -s -N -e"$sql" 2>&1)
    if [[ $? != 0 ]]; then
      echo "FAILED!"
      echo ">>> $ERRORS"
      export MYSQL_PWD="$MYSQL_PASSWORD"
      false
      return
    fi
  done
  
  if ! execute_sql_file "$REALM_DB_NAME" "$SQL_FILE_BASE_REALM"; then
    echo "FAILED!"
    false
    return
  fi
  echo "SUCCESS"
  true
}

function create_all_databases_and_user
{
  echo
  read -e -p "All previous changes to database will be lost. Are you sure[y/N]? " CHANGESETTING
  if [[ ! "$CHANGESETTING" =~ ^[Yy]$ ]]; then
      return
  fi
  echo

  if ! create_db_user_and_set_privileges; then
    return
  fi

  if ! create_and_fill_world_db; then
    return
  fi

  if ! create_and_fill_char_db; then
    return
  fi

  if ! create_and_fill_realm_db; then
    return
  fi
}

function delete_all_databases_and_user
{
  echo -n "> Deleting all database and user in database..."
  sqlcreate+=("$SQL_DROP_DATABASE_USER")
  sqlcreate+=("$SQL_DROP_WORLD_DB")
  sqlcreate+=("$SQL_DROP_CHAR_DB")
  sqlcreate+=("$SQL_DROP_REALM_DB")
  export MYSQL_PWD="$ROOTPASSWORD"
  for sql in "${sqlcreate[@]}"
  do
    ERRORS=$("$MYSQL_EXE" -u"$ROOTUSERNAME" -h"$MYSQL_HOST" -P"$MYSQL_PORT" -s -N -e"$sql" 2>&1)
    if [[ $? != 0 ]]; then
      echo "FAILED!"
      echo ">>> $ERRORS"
      false
      return
    fi
  done
  echo "SUCCESS"
  unset sqlcreate
  export MYSQL_PWD="$MYSQL_PASSWORD"
  true
}

function manage_new_databases
{
  while true
  do
    clear
    print_underline "Create databases and fill them with latest data"
    echo
    echo
    if [ "$ROOTSUCCESS" = false ]; then
      set_try_root_connect_to_db true;
    else
      set_try_root_connect_to_db false;
    fi
    
    if [ "$ROOTSUCCESS" = false ]; then
      echo "Failed to connect to database with root access!"
    else
      echo "Successfully connected to database with root access."
    fi
    echo
    echo
    echo "> 1) Setting up root access"
    echo "> 2) Create all databases and user"
    echo "> 3) Create and fill character database"
    echo "> 4) Create and fill world database"
    echo "> 5) Create and fill realmd database"
    echo "> 6) Create 'core user' for db and set its default privileges"
    echo "> 7) Delete all databases and users"
    echo "> 9) Return to main menu"
    echo
    read -n 1 -e -p "Please enter your choice.....: " CHOICE

    case $CHOICE in
    "1") ROOTSUCCESS=false;;
    "2") create_all_databases_and_user; wait_key;;
    "3") create_and_fill_world_db; wait_key;;
    "4") create_and_fill_char_db; wait_key;;
    "5") create_and_fill_realm_db; wait_key;;
    "6") create_db_user_and_set_privileges; wait_key;;
    "7") delete_all_databases_and_user; wait_key;;
    *) break;;
  esac
  done
}

function print_realm_list
{
  printf "%-4.4s| %-24.24s| %-24.24s| %-5.5s| %-16.16s\n" "Id" "Name" "Address" "Port" "Builds"
  printf "%0.1s" "-"{1..80};printf "\n"
  while read line
  do
    # clean the result that might contain LF or CR char
    line=${line//[$'\r\n']}
    CURRENT_REALM_LIST+=("$line")

    # fill our array variable
    IFS=$'\t'; realmdata=($line); IFS="$OLDIFS"

    # split result so we can print them on specific places (result are separed using tab) realmdata=($line)
    printf "%-4.4s| %-24.24s| %-24.24s| %-5.5s| %-16.16s\n" "${realmdata[0]}" "${realmdata[1]}" "${realmdata[2]}" "${realmdata[3]}" "${realmdata[9]}"
    printf "%0.1s" "-"{1..80};printf "\n"
  done < <($MYSQL_COMMAND $REALM_DB_NAME -N -e "${SQL_QUERY_REALM_LIST}")
}

function realm_edit
{
  local found=false
  local choice
  read -e -p "Please enter your realm id .....: " choice
  for realmdata in "${CURRENT_REALM_LIST[@]}"
  do
    # split result so we can print them on specific places (result are separed using tab)
    IFS=$'\t';realmdata=($realmdata); IFS="$OLDIFS"

    if [ ${realmdata[0]} = "$choice" ]; then
      found=true
      echo "found"
      break
    fi
  done
  if [ ! "$found" = true ]; then
    echo "> Unable to found the choosen id($choice)!"
    return
  fi
  local orival="$realmdata"
  read -e -p "Enter realm id.....................: " -i "${realmdata[0]}" realmdata[0]
  read -e -p "Enter realm name...................: " -i "${realmdata[1]}" realmdata[1]
  read -e -p "Enter realm address................: " -i "${realmdata[2]}" realmdata[2]
  read -e -p "Enter realm port...................: " -i "${realmdata[3]}" realmdata[3]
  echo
  echo -n "Apllying realm changes ... "
  sql="$SQL_DELETE_REALM_ID'${realmdata[0]}'"
  if ! execute_sql_command "$REALM_DB_NAME" "$sql"; then
    echo "FAILED!"
    echo ">>> $MYSQL_ERROR"
    return
  fi

  sql="$SQL_INSERT_REALM_LIST('${realmdata[0]}','${realmdata[1]}','${realmdata[2]}','${realmdata[3]}');"
  if ! execute_sql_command "$REALM_DB_NAME" "$sql"; then
    echo "FAILED!"
    echo ">>> $MYSQL_ERROR"
    sql="$SQL_INSERT_REALM_LIST('${orival[0]}','${orival[1]}','${orival[2]}','${orival[3]}');"
    echo "> Trying to restore old datas ... "
    if ! execute_sql_command "$REALM_DB_NAME" "$sql"; then
      echo "FAILED!"
      echo ">>> $MYSQL_ERROR"
      return
      else
       echo "SUCCESS"
    fi
  fi
  echo "SUCCESS"
}

function realm_add
{
  clear
  local realmdata
  realmdata=("0" "CMaNGOS" "localhost" "8085")
  read -e -p "Enter realm id (should be unique id).: " -i "${realmdata[0]}" realmdata[0]
  read -e -p "Enter realm name.....................: " -i "${realmdata[1]}" realmdata[1]
  read -e -p "Enter realm address..................: " -i "${realmdata[2]}" realmdata[2]
  read -e -p "Enter realm port.....................: " -i "${realmdata[3]}" realmdata[3]

  local choice
  read -e -p "Is that correct [y/N]? " choice
  if [[ ! "$choice" =~ ^[Yy]$ ]]; then
      return
  fi

  sql="$SQL_INSERT_REALM_LIST('${realmdata[0]}','${realmdata[1]}','${realmdata[2]}','${realmdata[3]}');"
  execute_sql_command "$REALM_DB_NAME" "$sql" "Adding new realm to database ... "
}

function realm_remove
{
  local choice
  read -e -p "Please enter realm id that you want to delete.....: " choice

  sql="$SQL_DELETE_REALM_ID '$choice';"
  execute_sql_command "$REALM_DB_NAME" "$sql" "Deleting from realm to database ... "
}

function manage_realmlist
{
  while true
  do
    clear
    print_underline "Manage realm list"
    echo
    print_realm_list
    echo
    echo "> 1) Edit one realm"
    echo "> 2) Add a realm"
    echo "> 3) Remove a realm"
    echo "> 4) Refresh realm list"
    echo "> 9) Return to main menu"
    echo
    read -n 1 -e -p "Please enter your choice.....: " CHOICE

    case $CHOICE in
    "1") realm_edit; wait_key;;
    "2") realm_add; wait_key;;
    "3") realm_remove; wait_key;;
    "4") ;;
    *) break;;
  esac
  done
}


###############################################################################
# SCRIPT START                                                                #
###############################################################################

# Check if config file present
if [ ! -f $CONFIG_FILE ]
then
  save_settings
fi

# load config file
source $CONFIG_FILE

#initialize sql queries
set_sql_queries

#get some info from db install script
get_source_title_milestone

export MYSQL_PWD="$MYSQL_PASSWORD"
MYSQL_COMMAND="$MYSQL_EXE -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USERNAME"

# user menu
while true
do
  clear
  echo
  print_underline "Welcome to the CMaNGOS $EXPENSION databases manager" "="
  echo
  echo
  get_current_source_db_version
  check_dbs_accessibility false
  printf "%0.1s" "-"{1..80};printf "\n"
  printf "%-18s: %-30s  %-30s\n" "Database name" "Source version" "In database version"
  printf "%0.1s" "-"{1..80};printf "\n"
  printf "%-18.18s| %-30.30s| %-30.30s\n" $WORLD_DB_NAME $SOURCE_WORLDDB_VER $DB_WORLDDB_VERSION
  printf "%0.1s" "-"{1..80};printf "\n"
  printf "%-18.18s| %-30.30s| %-30.30s\n" $CHAR_DB_NAME $SOURCE_CHARACTERDB_VER $DB_CHARDB_VERSION
  printf "%0.1s" "-"{1..80};printf "\n"
  printf "%-18.18s| %-30.30s| %-30.30s\n" $REALM_DB_NAME $SOURCE_REALMDB_VER $DB_REALMDB_VERSION
  printf "%0.1s" "-"{1..80};printf "\n"
  echo
  #if check_dbs_accessibility
  #then
  #  printf "In database.........: %10s %10s %10s\n" $DB_WORLDDB_VERSION $DB_CHARDB_VERSION $DB_REALMDB_VERSION
  #fi

  echo
  echo
  echo "> 1) Manage mysql settings"
  echo "> 2) Retry to connect to database and retrieve dbs versions"
  echo "> 3) Create new fresh databases (root access required)"
  echo "> 4) Update all databases"
  echo "> 5) Manage realm list"
  echo "> 9) Quit"
  echo
  read -n 1 -e -p "Please enter your choice.....: " CHOICE

  case $CHOICE in
    "1") check_settings;;
    "2") ;;
    "3") manage_new_databases;;
    "4") update_databases; wait_key;;
    "5") manage_realmlist;;
    *) exit 0;;
  esac
done
  


exit 0
# check settings
while true
do
  check_settings
  if try_connect_to_db
  then
    break
  fi
  echo "> Failed to connect please verify your setting!"
done


if check_dbs_accessibility
then
  echo "> All database already exist and are accessible"
else
  echo "> Some databases are not accessible its either they dont exist or the mysql user have not right to access them"
  echo ">> $WORLD_DB_NAME version is '$DB_WORLDDB_VERSION'"
  echo ">> $CHAR_DB_NAME version is '$DB_CHARDB_VERSION'"
  echo ">> $REALM_DB_NAME version is '$DB_REALMDB_VERSION'"
fi


# check user choice (create/initialize or update)
if [ -z "$DB_WORLDDB_VERSION" ] && [ -z "$DB_CHARDB_VERSION" ] && [ -z "$DB_REALMDB_VERSION" ]
then
  echo "> Root access is needed to create users and required databases"
  echo ""
  while ! set_try_root_connect_to_db
  do
    echo "> Failed to connect to DB with root access"
    echo "> 1) Change root users/password"
    echo "> 2) Change DB settings"
    echo "> 3) Continue (only in case of empty database and you are sure user have correct right)"
    echo "> 4) Cancel"
    echo
    read -e -p "Please enter your choice.....: " -i "4" CHOICE

    case CHOICE in
      "2") change_mysql_settings;;
      "3") break;;
      "4") exit;;
    esac
  done
  
fi

echo
echo "You can choose to (re)create full database (root access required) or only update current databases"
read -e -p "Do you want to (c)reate full databases or only (u)pdate existings one? (i/u): " -i "u" INITVAR
if [ "$INITVAR" != "i" ]
then
  update_databases
else
  create_databases
fi
