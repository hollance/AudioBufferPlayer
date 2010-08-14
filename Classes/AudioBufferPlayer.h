/*!
 * \file AudioBufferPlayer.h
 */

#import <AudioToolbox/AudioToolbox.h>

/*! The number of Audio Queue buffers we keep in rotation. */
#define NUMBER_AUDIO_DATA_BUFFERS 3

@class AudioBufferPlayer;

/*!
 * The delegate for AudioBufferPlayer.
 *
 * The delegate should be set before the AudioBufferPlayer is started.
 */
@protocol AudioBufferPlayerDelegate

/*!
 * This method is invoked when the AudioBufferPlayer needs a buffer to be 
 * filled up with audio data.
 *
 * The delegate must fill \c buffer->mAudioData with up to 
 * \c buffer->mAudioDataBytesCapacity bytes of audio data. 
 * 
 * The delegate must set \c buffer->mAudioDataByteSize to the number of bytes 
 * of valid audio data that it wrote in the buffer.
 *
 * Writing 0 bytes is not recommended. If you have nothing to output, then it
 * is better to do:
 *
 * \code
 * memset(buffer->mAudioData, 0, buffer->mAudioDataBytesCapacity);
 * buffer->mAudioDataByteSize = buffer->mAudioDataBytesCapacity;
 * \endcode
 *
 * This method is called from an internal Audio Queue thread, so you may need 
 * to synchronize access to any shared objects it uses.
 *
 * @param audioBufferPlayer the AudioBufferPlayer that invokes this callback
 * @param buffer a pointer to an AudioQueueBuffer
 * @param audioFormat the data format of the buffer contents
 */
- (void)audioBufferPlayer:(AudioBufferPlayer*)audioBufferPlayer fillBuffer:(AudioQueueBufferRef)buffer format:(AudioStreamBasicDescription)audioFormat;

@end

/*!
 * AudioBufferPlayer makes it easy for you to do sound synthesis.
 *
 * It sets up an Audio Session and an Audio Queue for playback of live audio. 
 * You only have to provide a delegate that is responsible for filling up the 
 * audio buffers. 
 *
 * A bit of terminology:
 * - sample rate: the number of frames that is processed per second
 * - frame: a pair of left+right samples for stereo, a single sample for mono
 * - packet: because we are using uncompressed audio, a packet is the same as
 *   a frame (i.e. there is always 1 frame per packet)
 * - sample: a single 8, 16, 24 or 32-bit value from an audio waveform 
 *
 * You have options for specifying the sample rate, stereo or mono, and the
 * bit-depth of the output buffers. 
 * 
 * \note The buffers are always little-endian (both on simulator and on device).
 */
@interface AudioBufferPlayer : NSObject
{
	id<AudioBufferPlayerDelegate> delegate;
	BOOL playing;
	Float32 gain;
	AudioStreamBasicDescription audioFormat;

	/// the audio queue object being used for playback
	AudioQueueRef playQueue;
	
	/// the audio queue buffers for the playback audio queue
	AudioQueueBufferRef playQueueBuffers[NUMBER_AUDIO_DATA_BUFFERS];

	/// the number of audio data packets to use in each audio queue buffer
	UInt32 packetsPerBuffer;

	/// the number of bytes to use in each audio queue buffer
	UInt32 bytesPerBuffer;
}

/*! 
 * The delegate that fills up the audio buffers. This is a weak reference; the 
 * delegate is not retained. 
 */
@property (nonatomic, assign) id<AudioBufferPlayerDelegate> delegate;

/*! 
 * Whether the AudioBufferPlayer is currently active. If not active, it will 
 * not ask the delegate to fill up buffers.
 */
@property (nonatomic, assign, readonly) BOOL playing;

/*! The relative audio level for the playback audio queue. Defaults to 1.0. */
@property (nonatomic, assign) Float32 gain;	

/*! The audio format used for playback. */
@property (nonatomic, assign, readonly) AudioStreamBasicDescription audioFormat;

/*!
 * Initializes the AudioBufferPlayer.
 *
 * @param sampleRate the number of frames per second; typical values are 48000, 
 *        44100, 22050, 16000, 11025, 8000.
 * @param channels 2 for stereo, 1 for mono
 * @param bitsPerChannel the number of bits per audio sample; typical values 
 *        are 8, 16, 24, 32.
 * @param secondsPerBuffer How many seconds of audio will fit in each buffer.
 *        This equals the latency: if a buffer contains 1 second of autio data,
 *        then you have a latency of 1 second. This higher this value, the
 *        longer the delay between scheduling an event such as a note being
 *        played and actually hearing it. If this value is too low, playback 
 *        may stutter.
 *
 * @return the initialized AudioBufferPlayer object
 */
- (id)initWithSampleRate:(Float64)sampleRate channels:(UInt32)channels bitsPerChannel:(UInt32)bitsPerChannel secondsPerBuffer:(Float64)secondsPerBuffer;

/*!
 * Initializes the AudioBufferPlayer.
 *
 * @param sampleRate the number of frames per second; typical values are 48000, 
 *        44100, 22050, 16000, 11025, 8000.
 * @param channels 2 for stereo, 1 for mono
 * @param bitsPerChannel the number of bits per audio sample; typical values 
 *        are 8, 16, 24, 32.
 * @param packetsPerBuffer How many packets each audio buffer will contain.
 *        Higher values mean higher latency. If this value is too low, playback
 *        may stutter. Latency = packetsPerBuffer / sampleRate seconds.
 *
 * @return the initialized AudioBufferPlayer object
 */
- (id)initWithSampleRate:(Float64)sampleRate channels:(UInt32)channels bitsPerChannel:(UInt32)bitsPerChannel packetsPerBuffer:(UInt32)packetsPerBuffer;

/*!
 * After you create an AudioBufferPlayer instance, it is paused. You need to 
 * start it manually with this function.
 *
 * Be sure to set the delegate before you start the AudioBufferPlayer.
 */
- (void)start;

/*!
 * Pauses the AudioBufferPlayer. While paused, it will not ask for new buffers.
 */
- (void)stop;

@end
