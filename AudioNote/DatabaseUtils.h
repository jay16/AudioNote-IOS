//
//  Database_Utils.h
//  AudioNote
//
//  Created by lijunjie on 15-1-5.
//  Copyright (c) 2015年 Intfocus. All rights reserved.
//

#ifndef AudioNote_Database_Utils_h
#define AudioNote_Database_Utils_h

#import <Foundation/Foundation.h>
#import <sqlite3.h>

#define kDatabaseName @"voice_record.sqlite3"
#define myLog NSLog

@interface DatabaseUtils : NSObject

-(NSInteger) insertDBWithSQL: (NSString*) insertSQL;
-(NSMutableArray*) selectDBwithDate;

@end

#endif
