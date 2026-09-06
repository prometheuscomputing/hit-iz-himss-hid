package gov.nist.hit.core.api.config;

import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Configuration;

/**
 * hit-core's WebAppInitializer only scans gov.nist.hit.core and
 * gov.nist.auth.hit.core, so the beans declared in
 * gov.nist.hit.iz.web.config.IZWebBeanConfig were never registered from a
 * plain source build; the shipped images used to patch this class into the
 * WAR. Living in the scanned package, it widens the scan to gov.nist.
 */
@Configuration
@ComponentScan({"gov.nist"})
public class ExtraScanFix {
}
