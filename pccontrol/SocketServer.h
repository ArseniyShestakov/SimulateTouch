#ifndef SERVER_H
#define SERVER_H
#endif

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <Foundation/Foundation.h>

#define PORT 6000
#define ADDR "0.0.0.0"

void socketServer();
static void readStream(CFReadStreamRef readStream, CFStreamEventType eventype, void * clientCallBackInfo);
static void TCPServerAcceptCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info);
int notifyClient(UInt8* msg, CFWriteStreamRef client);

