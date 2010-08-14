
#import "AudioBufferPlayer.h"
#import "Synth.h"

@interface DemoViewController : UIViewController <AudioBufferPlayerDelegate>
{
	AudioBufferPlayer* player;
	Synth* synth;
	NSLock* synthLock;
}

- (IBAction)keyDown:(id)sender;
- (IBAction)keyUp:(id)sender;

@end
