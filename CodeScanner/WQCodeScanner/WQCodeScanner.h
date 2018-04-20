

#import <UIKit/UIKit.h>
/**
 *  屏幕 高 宽 边界
 */
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height
#define SCREEN_WIDTH  [UIScreen mainScreen].bounds.size.width
#define SCREEN_BOUNDS  [UIScreen mainScreen].bounds

#define TOP (SCREEN_HEIGHT-220)/2
#define LEFT (SCREEN_WIDTH-220)/2

#define kScanRect CGRectMake(LEFT, TOP, 220, 220)
typedef NS_ENUM(NSInteger, WQCodeScannerType) {
    WQCodeScannerTypeAll = 0,   //default, scan QRCode and barcode
    WQCodeScannerTypeQRCode,    //scan QRCode only
    WQCodeScannerTypeBarcode,   //scan barcode only
};

@interface WQCodeScanner : UIViewController

@property (nonatomic, assign) WQCodeScannerType scanType;
@property (nonatomic, copy) NSString *titleStr;
@property (nonatomic, copy) NSString *tipStr;

@property (nonatomic, copy) void(^resultBlock)(NSString *value);
/**
 *  读取图片中二维码信息
 *
 *  @param image 图片
 *
 *  @return 二维码内容
 */
+(NSString *)readQRCodeFromImage:(UIImage *)image;
/**
 *  生成二维码图片
 *
 *  @param QRString  二维码内容
 *  @param sizeWidth 图片size（正方形）
 *  @param color     填充色
 *
 *  @return  二维码图片
 */
+(UIImage *)createQRimageString:(NSString *)QRString sizeWidth:(CGFloat)sizeWidth fillColor:(UIColor *)color;
@end
