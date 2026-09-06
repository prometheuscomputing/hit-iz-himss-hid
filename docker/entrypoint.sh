#!/bin/bash
DB_HOST="${DB_HOST:-container-mysql}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-tool}"
DB_PASSWORD="${DB_PASSWORD:-db_password}"
DB_NAME="${DB_NAME:-toolname}"
DB_ACCOUNT_NAME="${DB_ACCOUNT_NAME:-${DB_NAME}_account}"

cat > /usr/local/tomcat/conf/context.xml <<XML
<?xml version="1.0" encoding="UTF-8"?>
<Context>
  <WatchedResource>WEB-INF/web.xml</WatchedResource>
  <WatchedResource>WEB-INF/tomcat-web.xml</WatchedResource>
  <WatchedResource>\${catalina.base}/conf/web.xml</WatchedResource>

  <Resource auth="Container"
    driverClassName="com.mysql.jdbc.Driver" maxActive="100" maxIdle="30"
    maxWait="10000" name="jdbc/base_tool_account_jndi"
    password="${DB_PASSWORD}" type="javax.sql.DataSource"
    url="jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_ACCOUNT_NAME}"
    username="${DB_USER}" />
  <Resource auth="Container"
    driverClassName="com.mysql.jdbc.Driver" maxActive="100" maxIdle="30"
    maxWait="10000" name="jdbc/base_tool_jndi"
    password="${DB_PASSWORD}" type="javax.sql.DataSource"
    url="jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}"
    username="${DB_USER}" />

  <Resources cacheMaxSize="512000" />
  <CookieProcessor sameSiteCookies="strict" />
</Context>
XML

echo "context.xml rewritten: ${DB_HOST}:${DB_PORT}, user=${DB_USER}, db=${DB_NAME}/${DB_ACCOUNT_NAME}"
rm -rf /usr/local/tomcat/webapps.dist
exec catalina.sh run
