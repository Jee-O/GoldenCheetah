/*
 * Copyright (c) 2013 Mark Liversedge (liversedge@gmail.com)
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRWFApiY; without even the implied warranty of MERCHWFApiABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc., 51
 * Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include "WFApi.h"

// WF API Headers
#import <WFConnector/WFHardwareConnector.h>
#import <WFConnector/WFConnectionParams.h>
#import <WFConnector/WFDeviceParams.h>
#import <WFConnector/hardware_connector_types.h>

// Utility
static QString toQString(const NSString *nsstr)
{
    NSRange range;
    range.location = 0;
    range.length = [nsstr length];
    QString result(range.length, QChar(0));
 
    unichar *chars = new unichar[range.length];
    [nsstr getCharacters:chars range:range];
    result = QString::fromUtf16(chars, range.length);
    delete[] chars;
    return result;
}

// Thi source file contains the private objc interface (WFBridge) that
// sits atop the Wahoo Fitness APIs at the top of the source file.
//
// This is then follwoed by the C++ public interface implementation that
// sits atop that private interface (WFBridge)

//----------------------------------------------------------------------
// Objective C -- Private interface / Bridge to WF API classes
//----------------------------------------------------------------------

@interface WFBridge : NSObject <WFHardwareConnectorDelegate> {

@public
    QPointer<WFApi> qtw; // the QT QObject public class

@private
    NSMutableArray* discoveredSensors;
}

@end

@implementation WFBridge


//**********************************************************************
// METHODS
//**********************************************************************


//version
-(NSString *) apiVersion { return [[WFHardwareConnector sharedConnector] apiVersion]; }

// State of BTLE support and hardware
-(BOOL)hasBTLESupport { return [[WFHardwareConnector sharedConnector] hasBTLESupport]; }

// By default BTLE is disabled
-(BOOL)isBTLEEnabled { return [[WFHardwareConnector sharedConnector] isBTLEEnabled]; }
-(BOOL)enableBTLE:(BOOL)bEnable inBondingMode:(BOOL)bBondingMode {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    bool result = [[WFHardwareConnector sharedConnector] enableBTLE:bEnable inBondingMode:bBondingMode];
    [pool drain];
    return result;
}

// initialise by getting the WF API singleton
-(id)init
{
    // initialise
    discoveredSensors = [[NSMutableArray arrayWithCapacity:10] retain];
    [[WFHardwareConnector sharedConnector] setDelegate:self];
    [self enableBTLE:TRUE inBondingMode:false];
    return self;
}
// ready to scan
-(BOOL)isCommunicationHWReady { return [[WFHardwareConnector sharedConnector] isCommunicationHWReady]; }

// current State
-(int)currentState { return [[WFHardwareConnector sharedConnector] currentState]; }
// scan
-(BOOL)discoverDevicesOfType:(WFSensorType_t)eSensorType onNetwork:(WFNetworkType_t)eNetworkType searchTimeout:(NSTimeInterval)timeout
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [discoveredSensors removeAllObjects];
    [[WFHardwareConnector sharedConnector] discoverDevicesOfType:eSensorType onNetwork:eNetworkType searchTimeout:timeout]; //XXX ignoringreturn
    [pool drain];
    return true;
}
-(int)deviceCount { return [discoveredSensors count]; }
-(NSString*)deviceUUID:(int)n
{
    WFDeviceParams* devParams = (WFDeviceParams*)[discoveredSensors objectAtIndex:n];
    return devParams.deviceUUIDString;
}

//**********************************************************************
// EVENTS / SIGNALS
//**********************************************************************

// WFHardwareConnectorDelegate Functions
-(void)hardwareConnector:(WFHardwareConnector*)hwConnector connectedSensor:(WFSensorConnection*)connectionInfo
{
    qtw->connectedSensor(connectionInfo);
}

-(void)hardwareConnector:(WFHardwareConnector*)hwConnector didDiscoverDevices:(NSSet*)connectionParams searchCompleted:(BOOL)bCompleted
{
    // add discovered devices.
    for (WFConnectionParams* connParams in connectionParams) {   
        [discoveredSensors addObject:connParams.device1];
    }   

    qtw->didDiscoverDevices([connectionParams count], bCompleted); //XXX convert array
}

-(void)hardwareConnector:(WFHardwareConnector*)hwConnector disconnectedSensor:(WFSensorConnection*)connectionInfo
{
    qtw->disconnectedSensor(connectionInfo);
}

-(void)hardwareConnector:(WFHardwareConnector*)hwConnector stateChanged:(WFHardwareConnectorState_t)currentState
{
    qtw->stateChanged();
}

-(void)hardwareConnectorHasData
{
    qtw->hasData();
}

-(void) hardwareConnector:(WFHardwareConnector*)hwConnector hasFirmwareUpdateAvailableForConnection:(WFSensorConnection*)connectionInfo required:(BOOL)required withWahooUtilityAppURL:(NSURL *)wahooUtilityAppURL
{
    qtw->hasFirmwareUpdateAvalableForConnection(); //XXX do what?
}

@end

//----------------------------------------------------------------------
// C++ Public interface
//----------------------------------------------------------------------

WFApi *_gc_wfapi = NULL;

// Construct the bridge to the WF API
WFApi::WFApi()
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    wf = [[WFBridge alloc] init];
    wf->qtw = this;
    [pool drain];
}

// Destroy the bridge to the WF API
WFApi::~WFApi()
{
    [wf release];
}

//**********************************************************************
// METHODS
//**********************************************************************

QString WFApi::apiVersion() { return toQString([wf apiVersion]); }
bool WFApi::isBTLEEnabled() { return [wf isBTLEEnabled]; }
bool WFApi::hasBTLESupport() { return [wf hasBTLESupport]; }
bool WFApi::isCommunicationHWReady() { return [wf isCommunicationHWReady]; }
bool WFApi::enableBTLE(bool enable, bool bondingmode) {
    return [wf enableBTLE:enable inBondingMode:bondingmode];
}
int WFApi::currentState() { return [wf currentState]; }

bool
WFApi::discoverDevicesOfType(int eSensorType, int eNetworkType, int timeout)
{
    // ignore ehat was passed for now...
    return [wf discoverDevicesOfType:WF_SENSORTYPE_BIKE_POWER onNetwork:WF_NETWORKTYPE_BTLE searchTimeout:5.00];
}

QString WFApi::deviceUUID(int n)
{
    if (n>=0 && n<deviceCount()) return toQString([wf deviceUUID:n]);
    else return "";
}

//**********************************************************************
// SLOTS
//**********************************************************************

void
WFApi::connectedSensor(void*)
{
qDebug()<<"connectedSensor";
}

void
WFApi::didDiscoverDevices(int count, bool finished)
{
    emit discoveredDevices(count,finished);
}

int
WFApi::deviceCount()
{
    return [wf deviceCount];
}

void
WFApi::disconnectedSensor(void*)
{
qDebug()<<"disconnectedSensor";
}

void
WFApi::hasData()
{
qDebug()<<"hasData";
}

void
WFApi::hasFirmwareUpdateAvalableForConnection()
{
qDebug()<<"hasFormware...";
}

void
WFApi::stateChanged()
{
qDebug()<<"state changed...";
emit currentStateChanged(currentState());
}