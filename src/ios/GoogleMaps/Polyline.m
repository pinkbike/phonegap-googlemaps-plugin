//
//  Polyline.m
//  SimpleMap
//
//  Created by masashi on 11/14/13.
//
//

#import "Polyline.h"

@implementation Polyline

-(void)setGoogleMapsViewController:(GoogleMapsViewController *)viewCtrl
{
  self.mapCtrl = viewCtrl;
}

-(GMSMutablePath *)decodePoly:(NSString *)encryptedPath
{
  double len = (double) [encryptedPath length];
  NSInteger half = (int) ceil(len/2.0);
  NSString *first = [encryptedPath substringToIndex:half];
  NSString *second = [encryptedPath substringFromIndex:half];

  NSString *encodedPath = [NSString stringWithFormat:@"%@%@", second, first];

  GMSMutablePath *path = [GMSMutablePath pathFromEncodedPath:encodedPath];
  return path;
}

-(NSMutableDictionary *)buildPolyline:(NSDictionary *)json
{
  GMSMutablePath *path;

  NSString *encryptedPath = [json objectForKey:@"encodedPath"];
  if ([encryptedPath length] > 0) {
    path = [self decodePoly:encryptedPath];
    //path = [GMSMutablePath pathFromEncodedPath:encryptedPath];
  }
  else {
    path = [GMSMutablePath path];
    NSArray *points = [json objectForKey:@"points"];
    int i = 0;
    NSDictionary *latLng;
    for (i = 0; i < points.count; i++) {
      latLng = [points objectAtIndex:i];
      [path addCoordinate:CLLocationCoordinate2DMake([[latLng objectForKey:@"lat"] floatValue], [[latLng objectForKey:@"lng"] floatValue])];
    }
  }

  // Create the Polyline, and assign it to the map.
  GMSPolyline *polyline = [GMSPolyline polylineWithPath:path];

  if ([[json valueForKey:@"visible"] boolValue]) {
    polyline.map = self.mapCtrl.map;
  }
  if ([[json valueForKey:@"geodesic"] boolValue]) {
    polyline.geodesic = YES;
  }
  NSArray *rgbColor = [json valueForKey:@"color"];
  polyline.strokeColor = [rgbColor parsePluginColor];

  polyline.strokeWidth = [[json valueForKey:@"width"] floatValue];
  polyline.zIndex = [[json valueForKey:@"zIndex"] floatValue];

  if ([[json valueForKey:@"tappable"] boolValue]) {
    polyline.tappable = YES;
  }
  else {
    polyline.tappable = NO;
  }

  NSString *id = [NSString stringWithFormat:@"polyline_%lu", (unsigned long)polyline.hash];
  [self.mapCtrl.overlayManager setObject:polyline forKey: id];
  polyline.title = id;

  NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
  [result setObject:id forKey:@"id"];

  [result setObject:[NSString stringWithFormat:@"%lu", (unsigned long)polyline.hash] forKey:@"hashCode"];

  return result;
}

-(void)createPolyline:(CDVInvokedUrlCommand *)command
{
  NSDictionary *json = [command.arguments objectAtIndex:1];

  NSMutableDictionary *result = [self buildPolyline:json];

  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void)createPolylines:(CDVInvokedUrlCommand *)command
{
  NSArray *polylinesOptionsArray = [command.arguments objectAtIndex:1];
  NSInteger numItems = [polylinesOptionsArray count];
  NSMutableArray *polylines = [NSMutableArray arrayWithCapacity:numItems];

  NSMutableDictionary *result;
  for (NSDictionary *json in polylinesOptionsArray) {
    result = [self buildPolyline:json];
    [polylines addObject:result];
  }

  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:polylines];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void)decodePath:(CDVInvokedUrlCommand *)command
{
  NSString *encryptedPath = [command.arguments objectAtIndex:1];
  GMSMutablePath *path = [self decodePoly:encryptedPath];
  int numPoints = [path count];

  NSMutableArray *latlngs = [NSMutableArray arrayWithCapacity:numPoints];

  CLLocationCoordinate2D point;
  NSMutableDictionary *latlng;
  int i = 0;
  for (i = 0; i < numPoints; i++) {
    point = [path coordinateAtIndex:i];
    latlng = [[NSMutableDictionary alloc] init];
    [latlng setObject:@(point.latitude).stringValue forKey:@"lat"];
    [latlng setObject:@(point.longitude).stringValue forKey:@"lng"];

    [latlngs addObject:latlng];
  }

  //double len = (double) [encryptedPath length];
  //NSInteger half = (int) ceil(len/2.0);
  //NSString *first = [encryptedPath substringToIndex:half];
  //NSString *second = [encryptedPath substringFromIndex:half];
  //NSString *encodedPath = [NSString stringWithFormat:@"%@%@", second, first];
  //NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
  //[result setObject:latlngs forKey:@"points"];
  //[result setObject:@(len).stringValue forKey:@"length"];
  //[result setObject:@(half).stringValue forKey:@"half"];
  //[result setObject:encryptedPath forKey:@"whole"];
  //[result setObject:first forKey:@"first"];
  //[result setObject:second forKey:@"second"];
  //[result setObject:encodedPath forKey:@"combined"];

  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:latlngs];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

/**
 * Set points
 * @params key
 */
-(void)setPoints:(CDVInvokedUrlCommand *)command
{
  NSString *polylineKey = [command.arguments objectAtIndex:1];
  GMSPolyline *polyline = [self.mapCtrl getPolylineByKey: polylineKey];
  GMSMutablePath *path = [GMSMutablePath path];

  NSArray *points = [command.arguments objectAtIndex:2];
  int i = 0;
  NSDictionary *latLng;
  for (i = 0; i < points.count; i++) {
    latLng = [points objectAtIndex:i];
    [path addCoordinate:CLLocationCoordinate2DMake([[latLng objectForKey:@"lat"] floatValue], [[latLng objectForKey:@"lng"] floatValue])];
  }
  [polyline setPath:path];


  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

/**
 * Set color
 * @params key
 */
-(void)setColor:(CDVInvokedUrlCommand *)command
{
  NSString *polylineKey = [command.arguments objectAtIndex:1];
  GMSPolyline *polyline = [self.mapCtrl getPolylineByKey: polylineKey];

  NSArray *rgbColor = [command.arguments objectAtIndex:2];
  [polyline setStrokeColor:[rgbColor parsePluginColor]];

  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

/**
 * Set width
 * @params key
 */
-(void)setWidth:(CDVInvokedUrlCommand *)command
{
  NSString *polylineKey = [command.arguments objectAtIndex:1];
  GMSPolyline *polyline = [self.mapCtrl getPolylineByKey: polylineKey];
  float width = [[command.arguments objectAtIndex:2] floatValue];
  [polyline setStrokeWidth:width];

  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

/**
 * Set z-index
 * @params key
 */
-(void)setZIndex:(CDVInvokedUrlCommand *)command
{
  NSString *polylineKey = [command.arguments objectAtIndex:1];
  GMSPolyline *polyline = [self.mapCtrl getPolylineByKey: polylineKey];
  NSInteger zIndex = [[command.arguments objectAtIndex:2] integerValue];
  [polyline setZIndex:(int)zIndex];

  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

/**
 * Set visibility
 * @params key
 */
-(void)setVisible:(CDVInvokedUrlCommand *)command
{
  NSString *polylineKey = [command.arguments objectAtIndex:1];
  GMSPolyline *polyline = [self.mapCtrl getPolylineByKey: polylineKey];
  Boolean isVisible = [[command.arguments objectAtIndex:2] boolValue];
  if (isVisible) {
    polyline.map = self.mapCtrl.map;
  } else {
    polyline.map = nil;
  }

  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}
/**
 * Set geodesic
 * @params key
 */
-(void)setGeodesic:(CDVInvokedUrlCommand *)command
{
  NSString *polylineKey = [command.arguments objectAtIndex:1];
  GMSPolyline *polyline = [self.mapCtrl getPolylineByKey: polylineKey];
  Boolean isGeodisic = [[command.arguments objectAtIndex:2] boolValue];
  [polyline setGeodesic:isGeodisic];

  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

/**
 * Remove the polyline
 * @params key
 */
-(void)remove:(CDVInvokedUrlCommand *)command
{
  NSString *polylineKey = [command.arguments objectAtIndex:1];
  GMSPolyline *polyline = [self.mapCtrl getPolylineByKey: polylineKey];
  polyline.map = nil;
  [self.mapCtrl removeObjectForKey:polylineKey];
  polyline = nil;

  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

@end
