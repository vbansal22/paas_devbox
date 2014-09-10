#!/usr/bin/env bash

. ${BUILDPACK_TEST_RUNNER_HOME}/lib/test_utils.sh

testCompileGetsDefaultSystemProperties() {
  createPom "$(withDependency)"

  compile

  assertCapturedSuccess

  assertCaptured "Installing Maven 3.0.5"
  assertFileMD5 "7d2bdb60388da32ba499f953389207fe"  ${CACHE_DIR}/.maven/bin/mvn
  assertTrue "mvn should be executable" "[ -x ${CACHE_DIR}/.maven/bin/mvn ]"


  assertCaptured "executing $CACHE_DIR/.maven/bin/mvn -B -Duser.home=$BUILD_DIR -Dmaven.repo.local=$CACHE_DIR/.m2/repository  -DskipTests=true clean install"
  assertCaptured "BUILD SUCCESS"
  assertCaptured "Installing OpenJDK 1.6"
  assertTrue "Java should be present in runtime." "[ -d ${BUILD_DIR}/.jdk ]"
  assertTrue "Java version file should be present." "[ -f ${BUILD_DIR}/.jdk/version ]"
  assertTrue "System properties file should be present in build dir." "[ -f ${BUILD_DIR}/system.properties ]"
}

createPom()
{
  cat > ${BUILD_DIR}/pom.xml <<EOF
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.mycompany.app</groupId>
  <artifactId>my-app</artifactId>
  <version>1.0-SNAPSHOT</version>
  <properties>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
  </properties>
  <dependencies>
$1
  </dependencies>
</project>
EOF
}

withDependency()
{
  cat <<EOF
    <dependency>
      <groupId>junit</groupId>
      <artifactId>junit</artifactId>
      <version>4.0</version>
      <type>jar</type>
      <scope>test</scope>
    </dependency>
EOF
}

createSettingsXml()
{
  if [ ! -z "$1" ]; then
    SETTINGS_FILE=$1
  else
    SETTINGS_FILE="${BUILD_DIR}/settings.xml"
  fi

  cat > $SETTINGS_FILE <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd">
  <profiles>
    <profile>
      <id>jboss-public-repository</id>
      <repositories>
        <repository>
          <id>jboss-no-bees</id>
          <name>JBoss Public Maven Repository Group</name>
          <url>http://repository.jboss.org/nexus/content/groups/public/</url>
        </repository>
      </repositories>
    </profile>
  </profiles>

  <activeProfiles>
    <activeProfile>jboss-public-repository</activeProfile>
  </activeProfiles>
</settings>
EOF
}


testCompile()
{
  createPom "$(withDependency)"

  compile

  assertCapturedSuccess

  assertCaptured "Installing Maven 3.0.5"
  assertFileMD5 "7d2bdb60388da32ba499f953389207fe" ${CACHE_DIR}/.maven/bin/mvn
  assertTrue "mvn should be executable" "[ -x ${CACHE_DIR}/.maven/bin/mvn ]"

  assertCaptured "executing $CACHE_DIR/.maven/bin/mvn -B -Duser.home=$BUILD_DIR -Dmaven.repo.local=$CACHE_DIR/.m2/repository  -DskipTests=true clean install"
  assertCaptured "BUILD SUCCESS"
}

testCompilationFailure()
{
  # Don't create POM to fail build

  compile

  assertCapturedError "Failed to build app with Maven"
}

testDownloadCaching()
{
  createPom

  # simulate a primed cache
  mkdir -p ${CACHE_DIR}/.maven
  mkdir -p ${CACHE_DIR}/.m2

  compile

  assertNotCaptured "Maven should not be installed again when already cached" "Installing Maven"
}

testNewAppsRemoveM2Cache()
{
  createPom
  rm -r ${CACHE_DIR} # simulate a brand new app without a cache dir

  assertFalse "Precondition: New apps should not have a CACHE_DIR prior to running" "[ -d ${CACHE_DIR} ]"
  assertFalse "Precondition: New apps should not have a removeM2Cache file prior to running" "[ -f ${CACHE_DIR}/removeM2Cache ]"

  compile

  assertCapturedSuccess
  assertTrue "removeM2Cache file should now exist in cache" "[ -f ${CACHE_DIR}/removeM2Cache ]"
  assertFalse ".m2 should not be copied to build dir" "[ -d ${BUILD_DIR}/.m2 ]"
  assertFalse ".maven should not be copied to build dir" "[ -d ${BUILD_DIR}/.maven ]"
}

testNonLegacyExistingAppsRemoveCache()
{
  createPom
  touch ${CACHE_DIR}/removeM2Cache # simulate a previous run with no cache dir

  assertTrue "Precondition: Existing apps should have a CACHE_DIR from previous run" "[ -d ${CACHE_DIR} ]"
  assertTrue "Precondition: Existing apps should have a removeM2Cache file from previous run" "[ -f ${CACHE_DIR}/removeM2Cache ]"

  compile

  assertCapturedSuccess
  assertTrue "removeM2Cache file should still exist in cache" "[ -f ${CACHE_DIR}/removeM2Cache ]"
  assertFalse ".m2 should not be copied to build dir" "[ -d ${BUILD_DIR}/.m2 ]"
  assertFalse ".maven should not be copied to build dir" "[ -d ${BUILD_DIR}/.maven ]"
}

testLegacyAppsKeepM2Cache()
{
  createPom

  assertTrue  "Precondition: Legacy apps should have a CACHE_DIR from a previous run" "[ -d ${CACHE_DIR} ]"
  assertFalse "Precondition: Legacy apps should not have a removeM2Cache file" "[ -f ${CACHE_DIR}/removeM2Cache ]"

  compile

  assertCapturedSuccess
  assertFalse "removeM2Cache file should not exist in cache" "[ -f ${CACHE_DIR}/removeM2Cache ]"
  assertEquals ".m2 should be copied to build dir" "" "$(diff -r ${CACHE_DIR}/.m2 ${BUILD_DIR}/.m2)"
  assertEquals ".maven should be copied to build dir" "" "$(diff -r ${CACHE_DIR}/.maven ${BUILD_DIR}/.maven)"
}

testCustomSettingsXml()
{
  createPom "$(withDependency)"
  createSettingsXml

  compile

  assertCapturedSuccess
  assertCaptured "Downloading: http://repository.jboss.org/nexus/content/groups/public"
}

testCustomSettingsXmlWithPath()
{
  createPom "$(withDependency)"
  mkdir -p $BUILD_DIR/support
  createSettingsXml "${BUILD_DIR}/support/settings.xml"

  export MAVEN_SETTINGS_PATH="${BUILD_DIR}/support/settings.xml"

  compile

  assertCapturedSuccess
  assertCaptured "Downloading: http://repository.jboss.org/nexus/content/groups/public"

  unset MAVEN_SETTINGS_PATH
}

testCustomSettingsXmlWithUrl()
{
  createPom "$(withDependency)"
  mkdir -p /tmp/.m2
  createSettingsXml "/tmp/.m2/settings.xml"

  export MAVEN_SETTINGS_URL="file:///tmp/.m2/settings.xml"

  compile

  assertCapturedSuccess
  assertCaptured "Installing settings.xml"
  assertCaptured "Downloading: http://repository.jboss.org/nexus/content/groups/public"

  unset MAVEN_SETTINGS_URL
}

testIgnoreSettingsOptConfig()
{
  createPom "$(withDependency)"
  export MAVEN_SETTINGS_OPT="-s nonexistant_file.xml"
  compile
  assertCapturedSuccess
  unset MAVEN_SETTINGS_OPT
}
