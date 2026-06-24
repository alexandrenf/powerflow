#import "MobileDeviceBridge.h"
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#include <stdlib.h>
#include <string.h>

#if MOBILEDEVICE_STUB

int32_t MDSubscribeDeviceNotifications(MDDeviceNotificationCallback callback, void *context, void **outSubscription) {
    (void)callback; (void)context;
    if (outSubscription) { *outSubscription = NULL; }
    return 0;
}
void MDUnsubscribeDeviceNotifications(void *subscription) { (void)subscription; }
void MDRunCurrentRunLoop(void) {}
char *MDCopyDeviceUDID(void *deviceRef) { (void)deviceRef; return strdup("STUB-UDID"); }
MDInterfaceType MDGetInterfaceType(void *deviceRef) { (void)deviceRef; return MDInterfaceUSB; }
char *MDCopyDeviceName(void *deviceRef) { (void)deviceRef; return strdup("Stub iPhone"); }
int32_t MDPrepareDevice(void *deviceRef) { (void)deviceRef; return 0; }
void MDReleaseDevice(void *deviceRef) { (void)deviceRef; }
int32_t MDStartDiagnosticsRelay(void *deviceRef, MDServiceConnection **outConnection) {
    (void)deviceRef;
    static MDServiceConnection dummy;
    if (outConnection) { *outConnection = &dummy; }
    return 0;
}
void MDInvalidateServiceConnection(MDServiceConnection *connection) { (void)connection; }
int32_t MDRequestIORegistry(MDServiceConnection *connection, char **outPlistXML) {
    (void)connection;
    const char *xml =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
        "<plist version=\"1.0\"><dict><key>Diagnostics</key><dict>"
        "<key>IORegistry</key><dict>"
        "<key>IsCharging</key><true/>"
        "<key>CurrentCapacity</key><integer>80</integer>"
        "<key>AppleRawCurrentCapacity</key><integer>3200</integer>"
        "<key>AppleRawMaxCapacity</key><integer>4000</integer>"
        "<key>DesignCapacity</key><integer>4000</integer>"
        "<key>CycleCount</key><integer>100</integer>"
        "<key>UpdateTime</key><integer>1719000000</integer>"
        "<key>Temperature</key><integer>2800</integer>"
        "<key>AdapterDetails</key><dict><key>Name</key><string>USB-C</string><key>Watts</key><integer>20</integer></dict>"
        "<key>PowerTelemetryData</key><dict>"
        "<key>SystemPowerIn</key><integer>15000</integer>"
        "<key>SystemLoad</key><integer>12000</integer>"
        "<key>BatteryPower</key><integer>3000</integer>"
        "<key>AdapterEfficiencyLoss</key><integer>500</integer>"
        "</dict></dict></dict></dict></plist>";
    if (outPlistXML) { *outPlistXML = strdup(xml); }
    return 0;
}

#else

typedef void *AMDeviceRef;
typedef struct {
    AMDeviceRef device;
    int32_t action;
    void *subscription;
} AMDeviceNotificationCallbackInfo;

typedef void (*AMDeviceNotificationCallbackFn)(const AMDeviceNotificationCallbackInfo *, void *);

typedef struct AMDServiceConnection AMDServiceConnection;
typedef const AMDServiceConnection *AMDServiceConnectionRef;

static void *MobileDeviceHandle(void) {
    static void *handle;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = dlopen(
            "/Library/Apple/System/Library/PrivateFrameworks/MobileDevice.framework/MobileDevice",
            RTLD_LAZY
        );
    });
    return handle;
}

#define MD_SYM(name) ((__typeof__(name) *)dlsym(MobileDeviceHandle(), #name))

static char *CopyCFString(CFStringRef string) {
    if (!string) {
        return NULL;
    }
    CFIndex length = CFStringGetLength(string);
    CFIndex maxSize = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;
    char *buffer = malloc((size_t)maxSize);
    if (!buffer) {
        return NULL;
    }
    if (!CFStringGetCString(string, buffer, maxSize, kCFStringEncodingUTF8)) {
        free(buffer);
        return NULL;
    }
    return buffer;
}

static CFDictionaryRef CreateIORegistryRequest(void) {
    const void *keys[] = {
        CFSTR("EntryClass"),
        CFSTR("Request"),
    };
    const void *values[] = {
        CFSTR("IOPMPowerSource"),
        CFSTR("IORegistry"),
    };
    return CFDictionaryCreate(
        kCFAllocatorDefault,
        keys,
        values,
        2,
        &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks
    );
}

int32_t MDSubscribeDeviceNotifications(
    MDDeviceNotificationCallback callback,
    void *context,
    void **outSubscription
) {
    if (!callback || !outSubscription) {
        return -1;
    }
    AMDeviceNotificationCallbackFn subscribe = MD_SYM(AMDeviceNotificationSubscribe);
    if (!subscribe) {
        return -1;
    }
    subscribe((AMDeviceNotificationCallbackFn)callback, 0, 0, context, outSubscription);
    return 0;
}

void MDUnsubscribeDeviceNotifications(void *subscription) {
    if (!subscription) {
        return;
    }
    void (*unsubscribe)(void *) = MD_SYM(AMDeviceNotificationUnsubscribe);
    if (unsubscribe) {
        unsubscribe(subscription);
    }
}

void MDRunCurrentRunLoop(void) {
    CFRunLoopRun();
}

char *MDCopyDeviceUDID(void *deviceRef) {
    if (!deviceRef) {
        return NULL;
    }
    CFStringRef (*copyIdentifier)(AMDeviceRef) = MD_SYM(AMDeviceCopyDeviceIdentifier);
    if (!copyIdentifier) {
        return NULL;
    }
    CFStringRef identifier = copyIdentifier(deviceRef);
    char *result = CopyCFString(identifier);
    if (identifier) {
        CFRelease(identifier);
    }
    return result;
}

MDInterfaceType MDGetInterfaceType(void *deviceRef) {
    if (!deviceRef) {
        return MDInterfaceUnknown;
    }
    int32_t (*getInterfaceType)(AMDeviceRef) = MD_SYM(AMDeviceGetInterfaceType);
    if (!getInterfaceType) {
        return MDInterfaceUnknown;
    }
    return (MDInterfaceType)getInterfaceType(deviceRef);
}

char *MDCopyDeviceName(void *deviceRef) {
    if (!deviceRef) {
        return NULL;
    }
    CFTypeRef (*copyValue)(AMDeviceRef, CFStringRef, CFStringRef) = MD_SYM(AMDeviceCopyValue);
    if (!copyValue) {
        return NULL;
    }
    CFTypeRef value = copyValue(deviceRef, NULL, CFSTR("DeviceName"));
    if (!value) {
        return NULL;
    }
    if (CFGetTypeID(value) != CFStringGetTypeID()) {
        CFRelease(value);
        return NULL;
    }
    char *result = CopyCFString((CFStringRef)value);
    CFRelease(value);
    return result;
}

int32_t MDPrepareDevice(void *deviceRef) {
    if (!deviceRef) {
        return -1;
    }

    int32_t (*connect)(AMDeviceRef) = MD_SYM(AMDeviceConnect);
    int32_t (*isPaired)(AMDeviceRef) = MD_SYM(AMDeviceIsPaired);
    int32_t (*pair)(AMDeviceRef) = MD_SYM(AMDevicePair);
    int32_t (*validatePairing)(AMDeviceRef) = MD_SYM(AMDeviceValidatePairing);
    int32_t (*startSession)(AMDeviceRef) = MD_SYM(AMDeviceStartSession);

    if (!connect || !isPaired || !pair || !validatePairing || !startSession) {
        return -1;
    }

    if (connect(deviceRef) != 0) {
        return -2;
    }
    if (isPaired(deviceRef) != 1 && pair(deviceRef) != 0) {
        return -3;
    }
    if (validatePairing(deviceRef) != 0) {
        return -4;
    }
    if (startSession(deviceRef) != 0) {
        return -5;
    }
    return 0;
}

void MDReleaseDevice(void *deviceRef) {
    if (!deviceRef) {
        return;
    }
    void (*stopSession)(AMDeviceRef) = MD_SYM(AMDeviceStopSession);
    void (*disconnect)(AMDeviceRef) = MD_SYM(AMDeviceDisconnect);
    if (stopSession) {
        stopSession(deviceRef);
    }
    if (disconnect) {
        disconnect(deviceRef);
    }
}

int32_t MDStartDiagnosticsRelay(void *deviceRef, MDServiceConnection **outConnection) {
    if (!deviceRef || !outConnection) {
        return -1;
    }

    int32_t (*startService)(AMDeviceRef, CFStringRef, CFDictionaryRef, const AMDServiceConnectionRef *) =
        MD_SYM(AMDeviceSecureStartService);
    if (!startService) {
        return -1;
    }

    AMDServiceConnectionRef connection = NULL;
    int32_t result = startService(deviceRef, CFSTR("com.apple.mobile.diagnostics_relay"), NULL, &connection);
    if (result != 0 || !connection) {
        return result != 0 ? result : -2;
    }

    *outConnection = (MDServiceConnection *)connection;
    return 0;
}

void MDInvalidateServiceConnection(MDServiceConnection *connection) {
    if (!connection) {
        return;
    }
    void (*invalidate)(AMDServiceConnectionRef) = MD_SYM(AMDServiceConnectionInvalidate);
    if (invalidate) {
        invalidate(connection);
    }
}

static CFDictionaryRef CopyDiagnosticsDictionary(MDServiceConnection *connection) {
    int32_t (*sendMessage)(AMDServiceConnectionRef, CFDictionaryRef, CFPropertyListFormat) =
        MD_SYM(AMDServiceConnectionSendMessage);
    int32_t (*receiveMessage)(
        AMDServiceConnectionRef,
        CFDictionaryRef *,
        CFPropertyListFormat *,
        void *,
        void *,
        void *
    ) = MD_SYM(AMDServiceConnectionReceiveMessage);

    if (!sendMessage || !receiveMessage) {
        return NULL;
    }

    CFDictionaryRef request = CreateIORegistryRequest();
    if (!request) {
        return NULL;
    }

    int32_t sendResult = sendMessage(connection, request, kCFPropertyListXMLFormat_v1_0);
    CFRelease(request);
    if (sendResult != 0) {
        return NULL;
    }

    CFDictionaryRef response = NULL;
    int32_t receiveResult = receiveMessage(connection, &response, NULL, NULL, NULL, NULL);
    if (receiveResult != 0 || !response) {
        return NULL;
    }

    return response;
}

int32_t MDRequestIORegistry(MDServiceConnection *connection, char **outPlistXML) {
    if (!connection || !outPlistXML) {
        return -1;
    }

    CFDictionaryRef response = CopyDiagnosticsDictionary(connection);
    if (!response) {
        return -2;
    }

    CFDataRef xmlData = CFPropertyListCreateData(
        kCFAllocatorDefault,
        response,
        kCFPropertyListXMLFormat_v1_0,
        0,
        NULL
    );
    CFRelease(response);

    if (!xmlData) {
        return -3;
    }

    const UInt8 *bytes = CFDataGetBytePtr(xmlData);
    CFIndex length = CFDataGetLength(xmlData);
    char *buffer = malloc((size_t)length + 1);
    if (!buffer) {
        CFRelease(xmlData);
        return -4;
    }
    memcpy(buffer, bytes, (size_t)length);
    buffer[length] = '\0';
    CFRelease(xmlData);

    *outPlistXML = buffer;
    return 0;
}

#endif
