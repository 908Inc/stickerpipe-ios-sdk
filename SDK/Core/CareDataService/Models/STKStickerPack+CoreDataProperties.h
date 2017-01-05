//
//  STKStickerPack+CoreDataProperties.h
//  
//
//  Created by vlad on 11/24/16.
//
//

#import "STKStickerPack+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface STKStickerPack (CoreDataProperties)

+ (NSFetchRequest<STKStickerPack *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *artist;
@property (nullable, nonatomic, copy) NSDate *updatedDate;
@property (nullable, nonatomic, copy) NSString *bannerUrl;
@property (nullable, nonatomic, copy) NSNumber *disabled;
@property (nullable, nonatomic, copy) NSNumber *order;
@property (nullable, nonatomic, copy) NSString *packDescription;
@property (nullable, nonatomic, copy) NSNumber *packID;
@property (nullable, nonatomic, copy) NSString *packName;
@property (nullable, nonatomic, copy) NSString *packTitle;
@property (nullable, nonatomic, copy) NSNumber *price;
@property (nullable, nonatomic, copy) NSString *pricePoint;
@property (nullable, nonatomic, copy) NSString *productID;
@property (nullable, nonatomic, retain) NSOrderedSet<STKSticker *> *stickers;

@end

@interface STKStickerPack (CoreDataGeneratedAccessors)

- (void)insertObject:(STKSticker *)value inStickersAtIndex:(NSUInteger)idx;
- (void)removeObjectFromStickersAtIndex:(NSUInteger)idx;
- (void)insertStickers:(NSArray<STKSticker *> *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeStickersAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInStickersAtIndex:(NSUInteger)idx withObject:(STKSticker *)value;
- (void)replaceStickersAtIndexes:(NSIndexSet *)indexes withStickers:(NSArray<STKSticker *> *)values;
- (void)addStickersObject:(STKSticker *)value;
- (void)removeStickersObject:(STKSticker *)value;
- (void)addStickers:(NSOrderedSet<STKSticker *> *)values;
- (void)removeStickers:(NSOrderedSet<STKSticker *> *)values;

@end

NS_ASSUME_NONNULL_END
