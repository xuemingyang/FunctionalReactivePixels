//
//  FRPPhotoImporter.m
//  FRP
//
//  Created by Ash Furrow on 10/13/2013.
//  Copyright (c) 2013 Ash Furrow. All rights reserved.
//

#import "FRPPhotoImporter.h"
#import "FRPPhotoModel.h"

@implementation FRPPhotoImporter

+(NSURLRequest *)popularURLRequest {
    return [AppDelegate.apiHelper urlRequestForPhotoFeature:PXAPIHelperPhotoFeaturePopular resultsPerPage:100 page:0 photoSizes:PXPhotoModelSizeThumbnail sortOrder:PXAPIHelperSortOrderRating except:PXPhotoModelCategoryNude];
}

+(NSURLRequest *)photoURLRequest:(FRPPhotoModel *)photoModel {
    return [AppDelegate.apiHelper urlRequestForPhotoID:photoModel.identifier.integerValue];
}

+(RACSubject *)importPhotos {
    RACSubject *subject = [RACSubject subject];
    
    NSURLRequest *request = [self popularURLRequest];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if (data) {
            id results = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            results = [FRPPhotoImporter getResultsDict];
            [subject sendNext:[[[results[@"photos"] rac_sequence] map:^id(NSDictionary *photoDictionary) {
                FRPPhotoModel *model = [FRPPhotoModel new];
                
                [self configurePhotoModel:model withDictionary:photoDictionary];
                [self downloadThumbnailForPhotoModel:model];
                
                return model;
            }] array]];
            [subject sendCompleted];
        }
        else {
            [subject sendError:connectionError];
        }
    }];
    
    return subject;
}

+ (NSDictionary *)getResultsDict {
    NSMutableDictionary *resDict = [NSMutableDictionary dictionary];
    NSMutableArray *array = [NSMutableArray array];
    for (int i = 0; i < 100; i++) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[@"name"] = [NSString stringWithFormat:@"第%d个", i];
                         dict[@"id"] = [NSString stringWithFormat:@"%d", i];
        dict[@"images"] = @[@{
                            @"url":@"http://img0.ph.126.net/JX4ESNkhTMWnkDnAgekxdg==/6597677796588620784.jpg",
                            @"size":@"3"
                           },
                            @{
                                @"url":@"http://img1.ph.126.net/srYQKelZKBYBsU8HObn0rQ==/3786682861788771964.jpg",
                                @"size":@"4"
                                }];
        dict[@"comments_count"] = [NSString stringWithFormat:@"%d", i];
        
        
        [array addObject:dict];
    }
    resDict[@"photos"] = array;
    return resDict;
}

+(RACSubject *)fetchPhotoDetails:(FRPPhotoModel *)photoModel {
    RACSubject *subject = [RACSubject subject];
    
    NSURLRequest *request = [self photoURLRequest:photoModel];
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if (data) {
            id results = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil][@"photo"];
            
            [self configurePhotoModel:photoModel withDictionary:results];
            [self downloadFullsizedImageForPhotoModel:photoModel];
            
            [subject sendNext:photoModel];
            [subject sendCompleted];
        }
        else {
            [subject sendError:connectionError];
        }
    }];
    
    return subject;
}

+(void)configurePhotoModel:(FRPPhotoModel *)photoModel withDictionary:(NSDictionary *)dictionary {
    // Basics details fetched with the first, basic request
    photoModel.photoName = dictionary[@"name"];
    photoModel.identifier = dictionary[@"id"];
    photoModel.photographerName = dictionary[@"user"][@"username"];
    photoModel.rating = dictionary[@"rating"];

    photoModel.thumbnailURL = [self urlForImageSize:3 inDictionary:dictionary[@"images"]];
    // Extneded attributes fetched with subsequent request
    if (dictionary[@"comments_count"]) {
        photoModel.fullsizedURL = [self urlForImageSize:4 inDictionary:dictionary[@"images"]];
    }
}

+(NSString *)urlForImageSize:(NSInteger)size inDictionary:(NSDictionary *)dictioary {
    /*
     images =     (
     {
     size = 3;
     url = "http://ppcdn.500px.org/49204370/b125a49d0863e0ba05d8196072b055876159f33e/3.jpg";
     }
     );
     */
    
    return [[[[[dictioary rac_sequence] filter:^BOOL(NSDictionary *value) {
        return [value[@"size"] integerValue] == size;
    }] map:^id(id value) {
        return value[@"url"];
    }] array] firstObject];
}

+(void)downloadThumbnailForPhotoModel:(FRPPhotoModel *)photoModel {
    NSAssert(photoModel.thumbnailURL, @"Thumbnail URL must not be nil");
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:photoModel.thumbnailURL]];
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        photoModel.thumbnailData = data;
    }];
}

+(void)downloadFullsizedImageForPhotoModel:(FRPPhotoModel *)photoModel {
    NSAssert(photoModel.fullsizedURL, @"Full sized URL must not be nil");
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:photoModel.fullsizedURL]];
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        photoModel.fullsizedData = data;
    }];
}

@end
