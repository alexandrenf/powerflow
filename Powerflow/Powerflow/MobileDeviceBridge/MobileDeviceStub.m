#import "MobileDeviceBridge.h"
#include <stdlib.h>
#include <string.h>

int32_t MDSubscribeDeviceNotifications(MDDeviceNotificationCallback callback, void *context, void **outSubscription) {
    (void)callback;
    (void)context;
    if (outSubscription) {
        *outSubscription = NULL;
    }
    return 0;
}

void MDUnsubscribeDeviceNotifications(void *subscription) {
    (void)subscription;
}

void MDRunCurrentRunLoop(void) {}

char *MDCopyDeviceUDID(void *deviceRef) {
    (void)deviceRef;
    return strdup("STUB-UDID");
}

MDInterfaceType MDGetInterfaceType(void *deviceRef) {
    (void)deviceRef;
    return MDInterfaceUSB;
}

char *MDCopyDeviceName(void *deviceRef) {
    (void)deviceRef;
    return strdup("Stub iPhone");
}

int32_t MDPrepareDevice(void *deviceRef) {
    (void)deviceRef;
    return 0;
}

void MDReleaseDevice(void *deviceRef) {
    (void)deviceRef;
}

int32_t MDStartDiagnosticsRelay(void *deviceRef, MDServiceConnection **outConnection) {
    (void)deviceRef;
    static MDServiceConnection dummy;
    if (outConnection) {
        *outConnection = &dummy;
    }
    return 0;
}

void MDInvalidateServiceConnection(MDServiceConnection *connection) {
    (void)connection;
}

int32_t MDRequestIORegistry(MDServiceConnection *connection, char **outPlistXML) {
    (void)connection;
    const char *xml =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
        "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" "
        "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
        "<plist version=\"1.0\"><dict>"
        "<key>Diagnostics</key><dict>"
        "<key>IORegistry</key><dict>"
        "<key>IsCharging</key><true/>"
        "<key>CurrentCapacity</key><integer>80</integer>"
        "<key>AppleRawCurrentCapacity</key><integer>3200</integer>"
        "<key>AppleRawMaxCapacity</key><integer>4000</integer>"
        "<key>DesignCapacity</key><integer>4000</integer>"
        "<key>CycleCount</key><integer>100</integer>"
        "<key>UpdateTime</key><integer>1719000000</integer>"
        "<key>Temperature</key><integer>2800</integer>"
        "<key>AdapterDetails</key><dict>"
        "<key>Name</key><string>USB-C</string>"
        "<key>Watts</key><integer>20</integer>"
        "</dict>"
        "<key>PowerTelemetryData</key><dict>"
        "<key>SystemPowerIn</key><integer>15000</integer>"
        "<key>SystemLoad</key><integer>12000</integer>"
        "<key>BatteryPower</key><integer>3000</integer>"
        "<key>AdapterEfficiencyLoss</key><integer>500</integer>"
        "</dict></dict></dict></dict></plist>";
    if (outPlistXML) {
        *outPlistXML = strdup(xml);
    }
    return 0;
}
