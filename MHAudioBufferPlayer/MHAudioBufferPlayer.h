
#import <AudioToolbox/AudioToolbox.h>

@class MHAudioBufferPlayer;

/*
 * This block is invoked when the MHAudioBufferPlayer needs a buffer to be
 * filled up with audio data.
 *
 * The block must fill buffer->mAudioData with up to mAudioDataBytesCapacity
 * bytes of audio data.
 * 
 * The block must set buffer->mAudioDataByteSize to the number of bytes of
 * valid audio data that it wrote in the buffer.
 *
 * Writing 0 bytes is not recommended. If you have nothing to output, then it
 * is better to do:
 *
 *     memset(buffer->mAudioData, 0, buffer->mAudioDataBytesCapacity);
 *     buffer->mAudioDataByteSize = buffer->mAudioDataBytesCapacity;
 *
 * This method is called from an internal Audio Queue thread, so you may need 
 * to synchronize access to any shared objects it uses.
 */
typedef void (^MHAudioBufferPlayerBlock)(AudioQueueBufferRef buffer, AudioStreamBasicDescription audioFormat);

/*
 * MHAudioBufferPlayer makes it easy for you to do sound synthesis.
 *
 * It sets up an Audio Session and an Audio Queue for playback of live audio. 
 * You only have to provide a block that is responsible for filling up the
 * audio buffers. 
 *
 * A bit of terminology:
 * - sample rate: the number of frames that is processed per second
 * - frame: a pair of left+right samples for stereo; a single sample for mono
 * - packet: because we are using uncompressed audio, a packet is the same as
 *   a frame (i.e. there is always 1 frame per packet)
 * - sample: a single 8, 16, 24 or 32-bit value from an audio waveform 
 *
 * You have options for specifying the sample rate, stereo or mono, and the
 * bit-depth of the output buffers. 
 * 
 * Note: The buffers are always assumed to be little-endian (both on simulator
 * and on a device).
 */
@interface MHAudioBufferPlayer : NSObject

/* The block that fills up the audio buffers. */
@property (nonatomic, copy) MHAudioBufferPlayerBlock block;

/*
 * Whether the MHAudioBufferPlayer is currently active. If not active, it will
 * not ask the block to fill up buffers.
 */
@property (nonatomic, assign, readonly) BOOL playing;

/* The relative audio level for the playback audio queue. Defaults to 1.0f. */
@property (nonatomic, assign) Float32 gain;	

/* The audio format used for playback. */
@property (nonatomic, assign, readonly) AudioStreamBasicDescription audioFormat;

/*
 * Initializes the MHAudioBufferPlayer.
 *
 * @param sampleRate the number of frames per second; typical values are 48000, 
 *        44100, 22050, 16000, 11025, 8000.
 * @param channels 2 for stereo, 1 for mono.
 * @param bitsPerChannel the number of bits per audio sample; typical values 
 *        are 8, 16, 24, 32.
 * @param secondsPerBuffer How many seconds of audio will fit in each buffer.
 *        This equals the latency; if a buffer contains 1 second of audio data,
 *        then you have a latency of 1 second. This higher this value, the
 *        longer the delay between scheduling an event such as a note being
 *        played and actually hearing it. If this value is too low, playback 
 *        may stutter.
 */
- (id)initWithSampleRate:(Float64)sampleRate channels:(UInt32)channels bitsPerChannel:(UInt32)bitsPerChannel secondsPerBuffer:(Float64)secondsPerBuffer;

/*
 * Initializes the MHAudioBufferPlayer.
 *
 * @param sampleRate the number of frames per second; typical values are 48000, 
 *        44100, 22050, 16000, 11025, 8000.
 * @param channels 2 for stereo, 1 for mono.
 * @param bitsPerChannel the number of bits per audio sample; typical values 
 *        are 8, 16, 24, 32.
 * @param packetsPerBuffer How many packets each audio buffer will contain.
 *        Higher values mean higher latency. If this value is too low, playback
 *        may stutter. Latency = packetsPerBuffer / sampleRate seconds.
 */
- (id)initWithSampleRate:(Float64)sampleRate channels:(UInt32)channels bitsPerChannel:(UInt32)bitsPerChannel packetsPerBuffer:(UInt32)packetsPerBuffer;

/*
 * After you create an MHAudioBufferPlayer instance, it is paused. You need to
 * start it manually with this function.
 *
 * Be sure to set the block before you start the MHAudioBufferPlayer.
 */
- (void)start;

/*
 * Pauses the MHAudioBufferPlayer. While paused, it will not ask for new buffers.
 */
- (void)stop;

@end
