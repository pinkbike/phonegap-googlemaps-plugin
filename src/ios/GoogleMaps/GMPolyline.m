//
//  GMPolyline.m
//  SimpleMap
//
//  Created by masashi on 11/14/13.
//
//

#import "GMPolyline.h"

@implementation GMPolyline

-(void)setGoogleMapsViewController:(GoogleMapsViewController *)viewCtrl
{
  self.mapCtrl = viewCtrl;
}

-(GMSMutablePath *)decodeEncodedPath:(NSString *)obfuscatedPath
{
  NSString *encodedPath;
  @try {
    double len = (double) [obfuscatedPath length];

    int chunkSize = 5;
    int numChunks = (int) ceil(len/chunkSize);
    int pos = len;
    int start;
    NSRange range;
    NSString *chunk;
    NSMutableArray *chunks = [NSMutableArray arrayWithCapacity:numChunks];
    while (pos >= 0) {
      start = MAX(pos-chunkSize, 0);
      range = NSMakeRange(start, pos - start);
      chunk = [obfuscatedPath substringWithRange:range];
      [chunks addObject:chunk];
      pos -= chunkSize;
    }
    encodedPath = [chunks componentsJoinedByString:@""];
  }
  @catch (NSException *exception) {
    NSLog(@"Error parsing encrypted path");
    NSLog(@"%@", exception.reason);
    encodedPath = @"";
  }

  GMSMutablePath *path;
  @try {
    path = [GMSMutablePath pathFromEncodedPath:encodedPath];
  }
  @catch (NSException *exception) {
    NSLog(@"Error creating path from encodedPath");
    NSLog(@"%@", exception.reason);
    path = [GMSMutablePath path];
  }

  return path;
}

-(NSMutableDictionary *)buildPolyline:(NSDictionary *)json
{
  GMSMutablePath *path;
  NSString *encodedPath = [json objectForKey:@"encodedPath"];
  if ([encodedPath length] > 0) {
    path = [self decodeEncodedPath:encodedPath];
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

  // Create the GMPolyline, and assign it to the map.
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

  NSMutableDictionary *startLatLng = [NSMutableDictionary dictionary];
  CLLocationCoordinate2D startCoord = [path coordinateAtIndex:0];
  [startLatLng setObject:[NSNumber numberWithFloat:startCoord.latitude] forKey:@"lat"];
  [startLatLng setObject:[NSNumber numberWithFloat:startCoord.longitude] forKey:@"lng"];
  [result setObject:startLatLng forKey:@"startLatLng"];

  NSMutableDictionary *endLatLng = [NSMutableDictionary dictionary];
  CLLocationCoordinate2D endCoord = [path coordinateAtIndex:([path count]-1)];
  [endLatLng setObject:[NSNumber numberWithFloat:endCoord.latitude] forKey:@"lat"];
  [endLatLng setObject:[NSNumber numberWithFloat:endCoord.longitude] forKey:@"lng"];
  [result setObject:endLatLng forKey:@"endLatLng"];

  return result;
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
  NSString *encodedPath = [command.arguments objectAtIndex:1];
  GMSMutablePath *path = [self decodeEncodedPath:encodedPath];
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
 * Removes the polylines
 * @params key
 */
-(void)removeMultiple:(CDVInvokedUrlCommand *)command
{
  NSArray *polylineKeys = [command.arguments objectAtIndex:1];
  for (NSString *polylineKey in polylineKeys) {
    GMSPolyline *polyline = [self.mapCtrl getPolylineByKey: polylineKey];
    polyline.map = nil;
    [self.mapCtrl removeObjectForKey:polylineKey];
    polyline = nil;
  }

  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

@end