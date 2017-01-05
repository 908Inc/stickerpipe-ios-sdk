//
//  STKStatistic+CoreDataClass.h
//  
//
//  Created by vlad on 11/24/16.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

extern const struct STKStatisticAttributes {
    __unsafe_unretained NSString* action;
    __unsafe_unretained NSString* category;
    __unsafe_unretained NSString* label;
    __unsafe_unretained NSString* time;
    __unsafe_unretained NSString* value;
} STKStatisticAttributes;

@interface STKStatistic : NSManagedObject

- (NSDictionary*)dictionary;

@end

NS_ASSUME_NONNULL_END

#import "STKStatistic+CoreDataProperties.h"
