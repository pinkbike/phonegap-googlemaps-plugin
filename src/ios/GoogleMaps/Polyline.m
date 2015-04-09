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

-(GMSMutablePath *)decodePoly:(NSString *)encodedString
{
  // http://stackoverflow.com/questions/9217274/how-to-decode-the-google-directions-api-polylines-field-into-lat-long-points-in

  GMSMutablePath *path = [GMSMutablePath path];

  const char *bytes = [encodedString UTF8String];
  NSUInteger length = [encodedString lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
  NSUInteger idx = 0;

  float latitude = 0;
  float longitude = 0;
  while (idx < length) {
    char byte = 0;
    int res = 0;
    char shift = 0;

    do {
      byte = bytes[idx++] - 63;
      res |= (byte & 0x1F) << shift;
      shift += 5;
    } while (byte >= 0x20);

    float deltaLat = ((res & 1) ? ~(res >> 1) : (res >> 1));
    latitude += deltaLat;

    shift = 0;
    res = 0;

    do {
      byte = bytes[idx++] - 0x3F;
      res |= (byte & 0x1F) << shift;
      shift += 5;
    } while (byte >= 0x20);

    float deltaLon = ((res & 1) ? ~(res >> 1) : (res >> 1));
    longitude += deltaLon;

    float finalLat = latitude * 1E-5;
    float finalLon = longitude * 1E-5;

    [path addCoordinate:CLLocationCoordinate2DMake(finalLat, finalLon)];
  }

  return path;
}

-(NSMutableDictionary *)buildPolyline:(NSDictionary *)json
{
  GMSMutablePath *path;

  NSString *encodedPath = [json objectForKey:@"encodedPath"];
  if (encodedPath) {
    path = [self decodePoly:[json valueForKey:@"encodedPath"]];
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

  polyline.tappable = YES;

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
