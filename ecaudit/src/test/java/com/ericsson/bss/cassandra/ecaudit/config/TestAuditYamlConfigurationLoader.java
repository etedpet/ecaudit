/*
 * Copyright 2018 Telefonaktiebolaget LM Ericsson
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.ericsson.bss.cassandra.ecaudit.config;

import java.net.URL;
import java.util.Properties;

import org.junit.Test;

import org.apache.cassandra.exceptions.ConfigurationException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatExceptionOfType;

public class TestAuditYamlConfigurationLoader
{
    @Test
    public void testEmptyPropertyThrowsConfigurationException()
    {
        Properties properties = new Properties();
        properties.put(AuditYamlConfigurationLoader.PROPERTY_CONFIG_FILE, "");

        AuditConfig config = givenLoadedConfig(properties);

        assertThatExceptionOfType(ConfigurationException.class)
        .isThrownBy(config::getYamlWhitelist);
        assertThatExceptionOfType(ConfigurationException.class)
        .isThrownBy(config::getLogFormat);
    }

    @Test
    public void testNonExistingPathPropertyThrowsConfigurationExceptionOnAllGetters()
    {
        Properties properties = new Properties();
        properties.put(AuditYamlConfigurationLoader.PROPERTY_CONFIG_FILE, "does_not_exist.yaml");

        AuditConfig config = givenLoadedConfig(properties);

        assertThatExceptionOfType(ConfigurationException.class)
        .isThrownBy(config::getYamlWhitelist);
        assertThatExceptionOfType(ConfigurationException.class)
        .isThrownBy(config::getLogFormat);
    }

    // If ecAudit is configured to use a yaml based whitelist we expect a file to be there
    // This behavior is different for other properties which may fall back to default values
    @Test
    public void testMissingDefaultFileForWhitelistThrowsConfigurationException()
    {
        AuditConfig config = givenLoadedDefaultConfig();

        assertThatExceptionOfType(ConfigurationException.class)
        .isThrownBy(config::getYamlWhitelist);
    }

    @Test
    public void testMissingWhitelistIsDefault()
    {
        Properties properties = getProperties("empty.yaml");

        AuditConfig config = givenLoadedConfig(properties);

        assertThat(config.getYamlWhitelist()).isEmpty();
    }

    @Test
    public void testEmptyWhitelistIsStillValid()
    {
        Properties properties = getProperties("missing_all.yaml");

        AuditConfig config = givenLoadedConfig(properties);

        assertThat(config.getYamlWhitelist()).isEmpty();
    }

    @Test
    public void testLoadWhitelistAllPresent()
    {
        Properties properties = getProperties("mock_configuration.yaml");

        AuditConfig config = givenLoadedConfig(properties);

        assertThat(config.getYamlWhitelist()).containsOnly("User1", "User2");
    }

    @Test
    public void testMissingDefaultFileForLogFormatIsDefault()
    {
        AuditConfig config = givenLoadedDefaultConfig();

        assertThat(config.getLogFormat()).isEqualTo("client:'${CLIENT}'|user:'${USER}'{?|batchId:'${BATCH_ID}'?}|status:'${STATUS}'|operation:'${OPERATION}'");
    }

    @Test
    public void testMissingLogFormatIsDefault()
    {
        Properties properties = getProperties("empty.yaml");

        AuditConfig config = givenLoadedConfig(properties);

        assertThat(config.getLogFormat()).isEqualTo("client:'${CLIENT}'|user:'${USER}'{?|batchId:'${BATCH_ID}'?}|status:'${STATUS}'|operation:'${OPERATION}'");
    }

    @Test
    public void testLoadingLogFileFormatFromConfiguration()
    {
        Properties properties = getProperties("mock_log_format.yaml");

        AuditConfig config = givenLoadedConfig(properties);

        assertThat(config.getLogFormat()).isEqualTo("user:{USER}, client:{CLIENT}");

        AuditYamlConfigurationLoader loader = AuditYamlConfigurationLoader.withProperties(properties);
        AuditYamlConfig loadedConfig = loader.loadConfig();
        assertThat(loadedConfig.getLogFormat()).isEqualTo("user:{USER}, client:{CLIENT}");
    }

    private AuditConfig givenLoadedConfig(Properties properties)
    {
        AuditYamlConfigurationLoader loader = AuditYamlConfigurationLoader.withProperties(properties);
        return new AuditConfig(loader);
    }

    private AuditConfig givenLoadedDefaultConfig()
    {
        AuditYamlConfigurationLoader loader = AuditYamlConfigurationLoader.withSystemProperties();
        return new AuditConfig(loader);
    }

    private static Properties getProperties(String fileName)
    {
        URL url = TestAuditYamlConfigurationLoader.class.getResource("/" + fileName);
        Properties properties = new Properties();
        properties.put(AuditYamlConfigurationLoader.PROPERTY_CONFIG_FILE, url.getPath());

        return properties;
    }
}