//
//  STKSticker+CoreDataProperties.m
//  
//
//  Created by vlad on 11/24/16.
//
//

#import "STKSticker+CoreDataProperties.h"

@implementation STKSticker (CoreDataProperties)

+ (NSFetchRequest<STKSticker *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"STKSticker"];
}

@dynamic packName;
@dynamic stickerID;
@dynamic stickerMessage;
@dynamic stickerName;
@dynamic usedCount;
@dynamic usedDate;
@dynamic stickerPack;
@dynamic order;
@dynamic stickerURL;

@end
