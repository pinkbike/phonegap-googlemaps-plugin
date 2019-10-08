//
//  GMPolyline.h
//  SimpleMap
//
//  Created by masashi on 11/14/13.
//
//

#import "GoogleMaps.h"
#import "MyPlgunProtocol.h"

@interface GMPolyline : CDVPlugin<MyPlgunProtocol>
@property (nonatomic, strong) GoogleMapsViewController* mapCtrl;
- (void)createPolylines:(CDVInvokedUrlCommand*)command;

- (void)setColor:(CDVInvokedUrlCommand*)command;
- (void)setWidth:(CDVInvokedUrlCommand*)command;
- (void)setPoints:(CDVInvokedUrlCommand*)command;
- (void)setZIndex:(CDVInvokedUrlCommand*)command;
- (void)setVisible:(CDVInvokedUrlCommand*)command;
- (void)removeMultiple:(CDVInvokedUrlCommand*)command;
- (void)setGeodesic:(CDVInvokedUrlCommand*)command;

@end