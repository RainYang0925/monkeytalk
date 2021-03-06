//
//  MTWebDriverResource.m
//  iWebDriver
//
//  Copyright 2009 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "MTWebDriverResource.h"
#import "MTWebDriverResponse.h"
#import "NSString+SBJSONMT.h"
//#import "MainViewController.h"
#import "MTerrorcodes.h"

@implementation MTWebDriverResource

@synthesize session = session_,
  allowOptionalArguments = allowOptionalArguments_;

- (id)initWithTarget:(id)target
             actions:(NSDictionary *)actionTable
{
  if (![super init])
    return nil;
  
  target_ = target;
  methodActions_ = actionTable;
  allowOptionalArguments_ = NO;
  
  return self;
}

- (id)initWithTarget:(id)target
           GETAction:(SEL)getAction
          POSTAction:(SEL)postAction
           PUTAction:(SEL)putAction
        DELETEAction:(SEL)deleteAction
{
  NSMutableDictionary *actions = [NSMutableDictionary dictionary];

  if (getAction != NULL)
    [actions setValue:[NSValue valueWithPointer:getAction] forKey:@"GET"];
  if (postAction != NULL)
    [actions setValue:[NSValue valueWithPointer:postAction] forKey:@"POST"];
  if (putAction != NULL)
    [actions setValue:[NSValue valueWithPointer:putAction] forKey:@"PUT"];
  if (deleteAction != NULL)
    [actions setValue:[NSValue valueWithPointer:deleteAction] forKey:@"DELETE"];
  
  return [self initWithTarget:target actions:actions];
}

+ (MTWebDriverResource *)resourceWithTarget:(id)target
                                GETAction:(SEL)getAction
                               POSTAction:(SEL)postAction
                                PUTAction:(SEL)putAction
                             DELETEAction:(SEL)deleteAction {
  return [[self alloc] initWithTarget:target
                             GETAction:getAction
                            POSTAction:postAction
                             PUTAction:putAction
                          DELETEAction:deleteAction];
}

// Helper method for people who don't care about put and delete
+ (MTWebDriverResource *)resourceWithTarget:(id)target
                                GETAction:(SEL)getAction
                               POSTAction:(SEL)postAction {
  return [self resourceWithTarget:target
                        GETAction:getAction
                       POSTAction:postAction
                        PUTAction:NULL
                     DELETEAction:NULL];
}



#pragma mark Creating a response

// Set the response's session
- (void)configureWebDriverResponse:(MTWebDriverResponse *)response {
  [response setSessionId:session_];
}

// Make an dictionary of objects containing the method arguments. Return nil on
// error.
- (NSDictionary *)getArgumentDictionaryFromData:(NSData *)data {
  id requestData = nil;
  
  if ([data length] > 0) {
    NSString *dataString =
    [[NSString alloc] initWithData:data
                          encoding:NSUTF8StringEncoding];
    
    requestData = [dataString JSONFragmentValue];
  }
  
  // The request data should contain an array of arguments.
  if (requestData != nil
      && ![requestData isKindOfClass:[NSDictionary class]]) {
    NSLog(@"Invalid argument list - Expecting a dictionary but given %@",
          requestData);
    return nil;
  }
  
  return (NSDictionary *)requestData;
}

// Validate the arguments are valid for this HTTP method + signature. Return
// a |MTWebDriverResponse| containing the error if we encountered one.
- (MTWebDriverResponse *)validateArgumentDictionary:(NSDictionary *)arguments
                                    forHTTPMethod:(NSString *)method
                                        signature:(NSMethodSignature *)signature {
  
  // If it was a PUT or POST, POST data is required (though an empty dictionary
  // may still be allowed).
  if (([method isEqualToString:@"PUT"] || [method isEqualToString:@"POST"])
      && arguments == nil) {
    return [MTWebDriverResponse responseWithError:@"Invalid arguments"];
  }

  // TODO(josephg): check argument type as well as number.
  
  return nil;
}

// Create a WebDriver response from a given selector.
- (MTWebDriverResponse *)createResponseFromSelector:(SEL)selector
                                          signature:(NSMethodSignature *)method
                                          arguments:(NSDictionary *)arguments {
  MTWebDriverResponse *response;
  id result;
  
  @try {
    if (arguments != nil) {
      // The first two arguments in the method are the target and selector.
      // NSInvocation will fill them in for us.  The 3rd argument should be
      // a dictionary of additional command parameters, initialized from the
      // request JSON data.
      if ([method numberOfArguments] > 2) {
        result = objc_msgSend(target_, selector, arguments);
      }
    } else {
      result = objc_msgSend(target_, selector);
    }
    
    if ([method methodReturnLength] == 0) {
      response = [MTWebDriverResponse responseWithValue:nil];
    } else {
      response = [MTWebDriverResponse responseWithValue:result];
    }
  }
  @catch (NSException * e) {
    NSLog(@"Method invocation error: %@", e);
    response = [MTWebDriverResponse responseWithError:e];
    
    // For easy debugging with Xcode, rethrow the exception here.
  }
  
  return response;
}

// Get the HTTP response to this request. This method is part of the
// |MTHTTPResource| protocol. It is the local entrypoint for creating a response.
- (id<MTHTTPResponse,NSObject>)httpResponseForQuery:(NSString *)query
                                           method:(NSString *)method
                                         withData:(NSData *)theData {
  SEL selector = [[methodActions_ objectForKey:method] pointerValue];
  NSMethodSignature *methodSignature = [target_ methodSignatureForSelector:selector];
  MTWebDriverResponse *response = nil;

  if (methodSignature == nil) {
    // Return a "405 Method Not Allowed" message. We should be setting an
    // "Allowed" header whose value is the list of methods supported by this
    // resource, but the CocoaHTTPServer framework we're using doesn't seem to
    // support it.
    // TODO: patch the server for headers
    response = [MTWebDriverResponse responseWithError:
                [NSString stringWithFormat:
                 @"Invalid method for resource: %@ %@", method, query]];
    [response setStatus:405];
    [self configureWebDriverResponse:response];
    return response;
  }
  
  NSDictionary *arguments = [self getArgumentDictionaryFromData:theData];
  
  response = [self validateArgumentDictionary:arguments
                                forHTTPMethod:method
                                    signature:methodSignature];
  
  // response != nil if validation failed.
  if (response != nil) {
    [self configureWebDriverResponse:response];
    return response;
  }
  
//  [[MainViewController sharedInstance]
//   describeLastAction:NSStringFromSelector(selector)];
  
  // Create response
  response = [self createResponseFromSelector:selector
                                      signature:methodSignature
                                      arguments:arguments];
  [self configureWebDriverResponse:response];
  return response;
}

// This is part of the |MTHTTPResource| protocol.
- (id<MTHTTPResource>)elementWithQuery:(NSString *)query { 
  return self;
}

@end


@implementation MTHTTPVirtualDirectory (MTWebDriverResource)

// Helper method to set JSON resources.
- (void)setMyWebDriverHandlerWithGETAction:(SEL)getAction
                                POSTAction:(SEL)postAction
                                 PUTAction:(SEL)putAction
                              DELETEAction:(SEL)deleteAction
                                  withName:(NSString *)name {
  [self setResource:[MTWebDriverResource resourceWithTarget:self
                                                GETAction:getAction
                                               POSTAction:postAction
                                                PUTAction:putAction
                                             DELETEAction:deleteAction]
           withName:name];  
}

// Calls above, but without put and delete.
- (void)setMyWebDriverHandlerWithGETAction:(SEL)getAction
                                POSTAction:(SEL)postAction
                                  withName:(NSString *)name {
  [self setMyWebDriverHandlerWithGETAction:getAction
                                POSTAction:postAction
                                 PUTAction:NULL
                              DELETEAction:NULL
                                  withName:name];
}

@end
