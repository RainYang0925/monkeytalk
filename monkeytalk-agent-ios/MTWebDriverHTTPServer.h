//
//  MTWebDriverHTTPServer.h
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

#import <Foundation/Foundation.h>
#import "MTHTTPServer.h"

// This is a special http server type which is the same as MTHTTPServer in every
// way except it accepts connections in a secondary run loop. This is important
// for event scheduling - so we can block and still recieve network events.
@interface MTWebDriverHTTPServer : MTHTTPServer {
  NSRunLoop *runLoop_;
}

@end
