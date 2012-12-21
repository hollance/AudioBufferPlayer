
/*
 * The maximum number of tones that can play simultaneously (polyphony). 
 * 
 * Note that a single MIDI note can be playing more than once: if you release 
 * a note and immediately play it again, the first one may still be ringing.
 */
#define MaxToneEvents 16

/*
 * Possible states for a ToneEvent.
 */
typedef enum
{
	ToneEventStateInactive = 0,  // ToneEvent is not used for playing a tone
	ToneEventStatePressed,       // ToneEvent is still playing normally
	ToneEventStateReleased,      // ToneEvent is released and ringing out
}
ToneEventState;

/*
 * Describes a tone.
 */
typedef struct
{
	ToneEventState state;  // the state of the tone
	int midiNote;          // the MIDI note number of the tone
	float phase;           // current step for the oscillator
	float fadeOut;         // used for fade-out on release of the tone
	float envStep;         // for stepping through the envelope
	float envDelta;        // how fast we're stepping through the envelope
}
ToneEvent;

/*
 * A very simple software synthesizer that plays a basic sine wave (organ tone) 
 * with a piano-like envelope.
 * 
 * Output is signed 16-bit little-endian, mono only.
 */
@interface Synth : NSObject

/*
 * Initializes the Synth.
 *
 * @param sampleRate the output will be generated for this sample rate
 * @return the initialized Synth object
 */
- (id)initWithSampleRate:(float)sampleRate;

/*
 * Schedules a new note for playing.
 *
 * If there are no more open slots (i.e. the polyphony limit is reached), then 
 * this new note is simply ignored.
 *
 * @param midiNote the MIDI note number
 */
- (void)playNote:(int)midiNote;

/*
 * Releases a note that is currently playing.
 *
 * If more than one tone with the corresponding MIDI note number is playing, 
 * they will all be released.
 *
 * @param midiNote the MIDI note number
 */
- (void)releaseNote:(int)midiNote;

/*
 * Fills up a buffer with a mono waveform in signed little-endian 16-bit format.
 *
 * @param buffer the buffer, which must be allocated by the caller
 * @param frames the number of frames available in the buffer
 * @return the number of frames actually written
 */
- (int)fillBuffer:(void *)buffer frames:(int)frames;

@end
