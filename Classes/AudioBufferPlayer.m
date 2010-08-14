
#import "AudioBufferPlayer.h"

@interface AudioBufferPlayer (Private)
- (void)setUpAudio;
- (void)tearDownAudio;
- (void)setUpAudioSession;
- (void)tearDownAudioSession;
- (void)setUpPlayQueue;
- (void)tearDownPlayQueue;
- (void)setUpPlayQueueBuffers;
- (void)primePlayQueueBuffers;
@end

static void interruptionListenerCallback(void* inUserData, UInt32 interruptionState)
{
	AudioBufferPlayer* player = (AudioBufferPlayer*) inUserData;
	if (interruptionState == kAudioSessionBeginInterruption)
	{
		[player tearDownAudio];
	}
	else if (interruptionState == kAudioSessionEndInterruption)
	{
		[player setUpAudio];
		[player start];
	}
}

static void playCallback(
	void* inUserData, AudioQueueRef inAudioQueue, AudioQueueBufferRef inBuffer)
{
	AudioBufferPlayer* player = (AudioBufferPlayer*) inUserData;
	if (player.playing)
	{
		[player.delegate audioBufferPlayer:player fillBuffer:inBuffer format:player.audioFormat];
		AudioQueueEnqueueBuffer(inAudioQueue, inBuffer, 0, NULL);
	}
}

@implementation AudioBufferPlayer

@synthesize delegate;
@synthesize playing;
@synthesize gain;
@synthesize audioFormat;

- (id)initWithSampleRate:(Float64)sampleRate channels:(UInt32)channels bitsPerChannel:(UInt32)bitsPerChannel secondsPerBuffer:(Float64)secondsPerBuffer
{
	return [self initWithSampleRate:sampleRate channels:channels bitsPerChannel:bitsPerChannel packetsPerBuffer:(UInt32)(secondsPerBuffer * sampleRate)];
}

- (id)initWithSampleRate:(Float64)sampleRate channels:(UInt32)channels bitsPerChannel:(UInt32)bitsPerChannel packetsPerBuffer:(UInt32)packetsPerBuffer_
{
	if ((self = [super init]))
	{
		playing = NO;
		delegate = nil;
		playQueue = NULL;
		gain = 1.0;

		audioFormat.mFormatID         = kAudioFormatLinearPCM;
		audioFormat.mSampleRate       = sampleRate;
		audioFormat.mChannelsPerFrame = channels;
		audioFormat.mBitsPerChannel   = bitsPerChannel;
		audioFormat.mFramesPerPacket  = 1;  // uncompressed audio
		audioFormat.mBytesPerFrame    = audioFormat.mChannelsPerFrame * audioFormat.mBitsPerChannel/8; 
		audioFormat.mBytesPerPacket   = audioFormat.mBytesPerFrame * audioFormat.mFramesPerPacket;
		audioFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger 
									  | kLinearPCMFormatFlagIsPacked; 

		packetsPerBuffer = packetsPerBuffer_;
		bytesPerBuffer = packetsPerBuffer * audioFormat.mBytesPerPacket;

		[self setUpAudio];
	}
	return self;
}

- (void)dealloc
{
	[self tearDownAudio];
	[super dealloc];
}

- (void)setUpAudio
{
	if (playQueue == NULL)
	{
		[self setUpAudioSession];
		[self setUpPlayQueue];
		[self setUpPlayQueueBuffers];
	}
}

- (void)tearDownAudio
{
	if (playQueue != NULL)
	{
		[self stop];
		[self tearDownPlayQueue];
		[self tearDownAudioSession];
	}
}

- (void)setUpAudioSession
{
	AudioSessionInitialize(
		NULL,
		NULL,
		interruptionListenerCallback,
		self
		);

	UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
	AudioSessionSetProperty(
		kAudioSessionProperty_AudioCategory,
		sizeof(sessionCategory),
		&sessionCategory
		);

	AudioSessionSetActive(true);
}

- (void)tearDownAudioSession
{
	AudioSessionSetActive(false);
}

- (void)setUpPlayQueue
{
	AudioQueueNewOutput(
		&audioFormat,
		playCallback,
		self, 
		NULL,                   // run loop
		kCFRunLoopCommonModes,  // run loop mode
		0,                      // flags
		&playQueue
		);

	self.gain = 1.0;
}

- (void)tearDownPlayQueue
{
	AudioQueueDispose(playQueue, YES);
	playQueue = NULL;
}

- (void)setUpPlayQueueBuffers
{
	for (int t = 0; t < NUMBER_AUDIO_DATA_BUFFERS; ++t)
	{
		AudioQueueAllocateBuffer(
			playQueue,
			bytesPerBuffer,
			&playQueueBuffers[t]
			);
	}
}

- (void)primePlayQueueBuffers
{
	for (int t = 0; t < NUMBER_AUDIO_DATA_BUFFERS; ++t)
	{
		playCallback(self, playQueue, playQueueBuffers[t]);
	}
}

- (void)start
{
	if (!playing)
	{
		playing = YES;
		[self primePlayQueueBuffers];
		AudioQueueStart(playQueue, NULL);
	}
}

- (void)stop
{
	if (playing)
	{
		AudioQueueStop(playQueue, TRUE);
		playing = NO;
	}
}

- (void)setGain:(Float32)gain_
{
	gain = gain_;

	AudioQueueSetParameter(
		playQueue,
		kAudioQueueParam_Volume,
		gain
		);
}

@end
