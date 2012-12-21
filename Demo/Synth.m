
#import "Synth.h"

const float AttackTime = 0.005f;
const float ReleaseTime = 0.5f;

@implementation Synth
{
	float _sampleRate;   // output will be generated for this sample rate
	float _gain;         // attenuation factor to prevent clipping

	float *_sine;        // look-up table for quick sin()
	int _sineLength;     // size of sine look-up table

	float *_envelope;    // look-up table for the envelope
	int _envLength;      // size of envelope look-up table

	ToneEvent _tones[MaxToneEvents];  // the slots for the tones
	
	float _pitches[128];  // fundamental frequencies for all MIDI note numbers
}

- (id)initWithSampleRate:(float)sampleRate
{
	if ((self = [super init]))
	{
		_sampleRate = sampleRate;
		_sine = NULL;
		_sineLength = 0;
		_envelope = NULL;
		_envLength = 0;
		_gain = 0.3f;

		for (int n = 0; n < MaxToneEvents; ++n)
			_tones[n].state = ToneEventStateInactive;

		[self equalTemperament];
		[self buildSineTable];
		[self buildEnvelope];
	}
	return self;
}

- (void)dealloc
{
	free(_sine);
	free(_envelope);
}

- (void)equalTemperament
{
	for (int n = 0; n < 128; ++n)
		_pitches[n] = 440.0f * powf(2, (n - 69)/12.0f);  // A4 = MIDI key 69
}

- (void)buildSineTable
{
	// Compute a sine table for a 1 Hz tone at the current sample rate.
	// We can quickly derive the sine wave for any other tone from this
	// table by stepping through it with the wanted pitch value.

	_sineLength = (int)_sampleRate;
	_sine = (float *)malloc(_sineLength * sizeof(float));

	for (int i = 0; i < _sineLength; ++i)
		_sine[i] = sinf(i * 2.0f * M_PI / _sineLength);
}

- (void)buildEnvelope
{
	// The envelope is a 2-second table with values between 0.0f and 1.0f.
	// Because lower tones last longer than higher tones, we will use a delta
	// value to step through this table. MIDI note number 64 has delta = 1.0f.

	_envLength = (int)_sampleRate * 2;  // 2 seconds
	_envelope = (float *)malloc(_envLength * sizeof(float));

	// This envelope shape approximates a piano tone with a sharp attack and
	// an exponential delay.

	int attackLength = (int)(AttackTime * _sampleRate);  // attack
	for (int i = 0; i < attackLength; ++i)
		_envelope[i] = (float)i / attackLength;

	for (int i = attackLength; i < _envLength; ++i)  // decay
	{
		float x = (i - attackLength)/_sampleRate;
		_envelope[i] = expf(-x * 3);
	}
}

- (void)playNote:(int)midiNote
{
	for (int n = 0; n < MaxToneEvents; ++n)
	{
		if (_tones[n].state == ToneEventStateInactive)  // find an empty slot
		{
			_tones[n].state = ToneEventStatePressed;
			_tones[n].midiNote = midiNote;
			_tones[n].phase = 0.0f;
			_tones[n].envStep = 0.0f;
			_tones[n].envDelta = midiNote / 64.0f;
			_tones[n].fadeOut = 1.0f;
			return;
		}
	}
}

- (void)releaseNote:(int)midiNote
{
	for (int n = 0; n < MaxToneEvents; ++n)
	{
		if (_tones[n].midiNote == midiNote && _tones[n].state != ToneEventStateInactive)
		{
			_tones[n].state = ToneEventStateReleased;
			
			// We don't exit the loop here, because the same MIDI note may be
			// playing more than once, and we need to stop them all.
		}
	}
}

- (int)fillBuffer:(void *)buffer frames:(int)frames
{
	SInt16* p = (SInt16 *)buffer;

	// We are going to render the frames one-by-one. For each frame, we loop
	// through all of the active ToneEvents and move them forward a single step
	// in the simulation. We calculate each ToneEvent's individual output and
	// add it to a mix value. Then we write that mix value into the buffer and
	// repeat this process for the next frame.

	for (int f = 0; f < frames; ++f)
	{
		float m = 0.0f;  // the mixed value for this frame

		for (int n = 0; n < MaxToneEvents; ++n)
		{
			if (_tones[n].state == ToneEventStateInactive)  // only active tones
				continue;
				
			// The envelope is precomputed and stored in a look-up table.
			// For MIDI note 64 we step through this table one sample at a
			// time but for other notes the "envStep" may be fractional.
			// We must perform an interpolation to find the envelope value
			// for the current step.

			int a = (int)_tones[n].envStep;   // integer part
			float b = _tones[n].envStep - a;  // decimal part
			int c = a + 1;
			if (c >= _envLength)  // don't wrap around
				c = a;
			float envValue = (1.0f - b)*_envelope[a] + b*_envelope[c];

			// Get the next envelope value. If there are no more values, 
			// then this tone is done ringing.

			_tones[n].envStep += _tones[n].envDelta;
			if (((int)_tones[n].envStep) >= _envLength)
			{
				_tones[n].state = ToneEventStateInactive;
				continue;
			}

			// The steps in the sine table are 1 Hz apart, but the pitch of
			// the tone (which is the value by which we step through the
			// table) may have a fractional value and fall in between two
			// table entries. We will perform a simple interpolation to get
			// the best possible sine value.

			a = (int)_tones[n].phase;  // integer part
			b = _tones[n].phase - a;   // decimal part
			c = a + 1;
			if (c >= _sineLength)  // wrap around
				c -= _sineLength;
			float sineValue = (1.0f - b)*_sine[a] + b*_sine[c];

			// Wrap round when we get to the end of the sine look-up table.

			_tones[n].phase += _pitches[_tones[n].midiNote];
			if (((int)_tones[n].phase) >= _sineLength)
				_tones[n].phase -= _sineLength;

			// Are we releasing the tone? Then fade out the tone quickly.
			// Note that we always keep stepping through the envelope, even
			// if we're fading out the note.

			if (_tones[n].state == ToneEventStateReleased)
			{
				// We don't change the envelope directly here because that
				// would interfere with how we calculate the decay envelope.
				// Instead, we use a separate "fadeOut" variable to fade out
				// the tone.

				_tones[n].fadeOut -= 1.0f / (ReleaseTime * _sampleRate);
				if (_tones[n].fadeOut <= 0.0f)
				{
					_tones[n].state = ToneEventStateInactive;
					continue;
				}
			}
			
			// Calculate the final sample value.
			float s = sineValue * envValue * _gain * _tones[n].fadeOut;

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

	return frames;
}

@end
