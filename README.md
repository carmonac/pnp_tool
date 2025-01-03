# Print & Play Card

Generate pdf ready to print cards with standard size

it is simplified tool based on pnp tool application, but due to pnp tool is only for Windows and it is very buggy I decided to create my own script in dart which can run in all platforms. In a future, I'll release a flutter multiplatform app with a UI to print with in any paper size with different card size (It is under development) and configurations.


------


## Usage

To run the program, you need to provide two arguments:

1. **Path to the image directory**: The directory where the card images are stored.
2. **Output PDF name**: The name of the generated PDF file.

### Example Execution

```bash
./pnp_card /path/to/directory cards.pdf
```

## Directory Structure

```
/path/to/directory/
├── 1_front.png
├── 1_back.jpg
├── 2_front.jpeg
├── global_back.png
```

### Specific Scenarios
1.	If 1_front.png exists but 1_back.jpg is missing, the program will use global_back.png as the back image for that card.
2.	If a back image (name_back) exists without a corresponding front image (name_front), the program will throw an error indicating the issue.