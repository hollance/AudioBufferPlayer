
#import <QuartzCore/CABase.h>
#import "Synth.h"

const float ATTACK_TIME = 0.005f;
const float RELEASE_TIME = 0.5f;

@interface Synth (Private)
- (void)equalTemperament;
- (void)buildSineTable;
- (void)buildEnvelope;
@end

@implementation Synth

- (id)initWithSampleRate:(float)sampleRate_
{
	if ((self = [super init]))
	{
		sampleRate = sampleRate_;
		sine = NULL;
		sineLength = 0;
		envelope = NULL;
		envLength = 0;
		gain = 0.3f;

		for (int n = 0; n < MAX_TONE_EVENTS; ++n)
			tones[n].state = STATE_INACTIVE;		

		[self equalTemperament];
		[self buildSineTable];
		[self buildEnvelope];
	}
	return self;
}

- (void)dealloc
{
	free(sine);
	free(envelope);
	[super dealloc];
}

- (void)equalTemperament
{
	for (int n = 0; n < 128; ++n)
		pitches[n] = 440.0f * powf(2, (n - 69)/12.0f);  // A4 = MIDI key 69
}

- (void)buildSineTable
{
	// Compute a sine table for a 1 Hz tone at the current sample rate.
	// We can quickly derive the sine wave for any other tone from this
	// table by stepping through it with the wanted pitch value.

	sineLength = (int)sampleRate;
	sine = (float*)malloc(sineLength*sizeof(float));
	for (int i = 0; i < sineLength; ++i)
		sine[i] = sinf(i * 2.0f * M_PI / sineLength);
}

- (void)buildEnvelope
{
	// The envelope is a 2-second table with values between 0.0f and 1.0f.
	// Because lower tones last longer than higher tones, we will use a delta
	// value to step through this table. MIDI note number 64 has delta = 1.0f.

	envLength = (int)sampleRate * 2;  // 2 seconds
	envelope = (float*)malloc(envLength*sizeof(float));

	// This envelope shape approximates a piano tone with a sharp attack and
	// an exponential delay.

	int attackLength = (int)(ATTACK_TIME * sampleRate);  // attack
	for (int i = 0; i < attackLength; ++i)
		envelope[i] = (float)i / attackLength;

	for (int i = attackLength; i < envLength; ++i)  // decay
	{
		float x = (i - attackLength)/sampleRate;
		envelope[i] = expf(-x * 3);
	}
}

- (void)playNote:(int)midiNote
{
	for (int n = 0; n < MAX_TONE_EVENTS; ++n)
	{
		if (tones[n].state == STATE_INACTIVE)  // find an empty slot
		{
			tones[n].state = STATE_PRESSED;
			tones[n].midiNote = midiNote;
			tones[n].phase = 0.0f;
			tones[n].envStep = 0.0f;
			tones[n].envDelta = midiNote / 64.0f;
			tones[n].fadeOut = 1.0f;
			return;
		}
	}
}

- (void)releaseNote:(int)midiNote
{
	for (int n = 0; n < MAX_TONE_EVENTS; ++n)
	{
		if (tones[n].midiNote == midiNote && tones[n].state != STATE_INACTIVE)
		{
			tones[n].state = STATE_RELEASED;
			
			// We don't exit the loop here, because the same MIDI note may be
			// playing more than once, and we need to stop them all.
		}
	}
}

- (int)fillBuffer:(void*)buffer frames:(int)frames
{
	SInt16* p = (SInt16*)buffer;

	//double startTime = CACurrentMediaTime();

	// We are going to render the frames one-by-one. For each frame, we loop
	// through all of the active ToneEvents and move them forward a single step
	// in the simulation. We calculate each ToneEvent's individual output and
	// add it to a mix value. Then we write that mix value into the buffer and 
	// repeat this process for the next frame.
	for (int f = 0; f < frames; ++f)
	{
		float m = 0.0f;  // the mixed value for this frame

		for (int n = 0; n < MAX_TONE_EVENTS; ++n)
		{
			if (tones[n].state == STATE_INACTIVE)  // only active tones
				continue;
				
			// The envelope is precomputed and stored in a look-up table.
			// For MIDI note 64 we step through this table one sample at a
			// time but for other notes the "envStep" may be fractional.
			// We must perform an interpolation to find the envelope value
			// for the current step.
			int a = (int)tones[n].envStep;   // integer part
			float b = tones[n].envStep - a;  // decimal part
			int c = a + 1;
			if (c >= envLength)  // don't wrap around
				c = a;
			float envValue = (1.0f - b)*envelope[a] + b*envelope[c];

			// Get the next envelope value. If there are no more values, 
			// then this tone is done ringing.
			tones[n].envStep += tones[n].envDelta;
			if (((int)tones[n].envStep) >= envLength)
			{
				tones[n].state = STATE_INACTIVE;
				continue;
			}

			// The steps in the sine table are 1 Hz apart, but the pitch of
			// the tone (which is the value by which we step through the
			// table) may have a fractional value and fall in between two
			// table entries. We will perform a simple interpolation to get
			// the best possible sine value.
			a = (int)tones[n].phase;  // integer part
			b = tones[n].phase - a;   // decimal part
			c = a + 1;
			if (c >= sineLength)  // wrap around
				c -= sineLength;
			float sineValue = (1.0f - b)*sine[a] + b*sine[c];

			// Wrap round when we get to the end of the sine look-up table.
			tones[n].phase += pitches[tones[n].midiNote];
			if (((int)tones[n].phase) >= sineLength)
				tones[n].phase -= sineLength;

			// Are we releasing the tone? Then fade out the tone quickly.
			// Note that we always keep stepping through the envelope, even
			// if we're fading out the note.
			if (tones[n].state == STATE_RELEASED)
			{
				// We don't change the envelope directly here because that
				// would interfere with how we calculate the decay envelope.
				// Instead, we use a separate "fadeOut" variable to fade out
				// the tone.
				tones[n].fadeOut -= 1.0f / (RELEASE_TIME * sampleRate);
				if (tones[n].fadeOut <= 0.0f)
				{
					tones[n].state = STATE_INACTIVE;
					continue;
				}
			}
			
			// Calculate the final sample value.
			float s = sineValue * envValue * gain * tones[n].fadeOut;
			
			// Clamp it to make sure it is within the [-1.0f, 1.0f] range.
			if (s > 1.0f)
				s = 1.0f;
			else if (s < -1.0f)
				s = -1.0f;

			// Add it to the mix.
			m += s;
		}

		// Write the sample mix to the buffer as a 16-bit word.
		p[f] = (SInt16)(m * 0x7FFF);
	}

	//NSLog(@"elapsed %g", CACurrentMediaTime() - startTime);

	return frames;
}

@end
