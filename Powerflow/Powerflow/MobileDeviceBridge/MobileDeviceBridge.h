#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum : int32_t {
    MDActionAttached = 1,
    MDActionDetached = 2,
    MDActionNotificationStopped = 3,
    MDActionPaired = 4,
} MDDeviceAction;

typedef enum : int32_t {
    MDInterfaceUnknown = 0,
    MDInterfaceUSB = 1,
    MDInterfaceWiFi = 2,
} MDInterfaceType;

typedef struct {
    void *deviceRef;
    MDDeviceAction action;
} MDDeviceNotificationInfo;

typedef void (*MDDeviceNotificationCallback)(
    const MDDeviceNotificationInfo *info,
    void *context
);

int32_t MDSubscribeDeviceNotifications(
    MDDeviceNotificationCallback callback,
    void *context,
    void **outSubscription
);
void MDUnsubscribeDeviceNotifications(void *subscription);
void MDRunCurrentRunLoop(void);

char *MDCopyDeviceUDID(void *deviceRef);
MDInterfaceType MDGetInterfaceType(void *deviceRef);
char *MDCopyDeviceName(void *deviceRef);

int32_t MDPrepareDevice(void *deviceRef);
void MDReleaseDevice(void *deviceRef);

typedef struct MDServiceConnection MDServiceConnection;

int32_t MDStartDiagnosticsRelay(
    void *deviceRef,
    MDServiceConnection **outConnection
);
void MDInvalidateServiceConnection(MDServiceConnection *connection);

int32_t MDRequestIORegistry(
    MDServiceConnection *connection,
    char **outPlistXML
);

#ifdef __cplusplus
}
#endif
