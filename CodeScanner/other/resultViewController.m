

#import "resultViewController.h"

@interface resultViewController (){
    UIWebView *webView;
}

@end

@implementation resultViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    webView = [[UIWebView alloc]initWithFrame:[UIScreen mainScreen].bounds];
    [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:_content]]];
    [self.view addSubview:webView];

}


@end
