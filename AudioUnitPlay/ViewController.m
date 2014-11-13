//
//  ViewController.m
//  AudioUnitPlay
//
//  Created by liumiao on 11/11/14.
//  Copyright (c) 2014 Chang Ba. All rights reserved.
//

#import "ViewController.h"
#import "AudioPlayer.h"
@interface ViewController ()
{
    AudioPlayer *player;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    player = [[AudioPlayer alloc]init];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)play:(id)sender {
    [player play];
}

- (IBAction)stop:(id)sender {
    [player stop];
}
- (IBAction)pause:(id)sender {
    [player pause];
}
@end
