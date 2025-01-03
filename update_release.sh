#!/bin/bash

REPO=$1
TAG_NAME=$2

cat <<EOF > README.md
# Print & Play Card Tool

## Download the latest version
- [Linux](https://github.com/${REPO}/releases/download/${TAG_NAME}/pnp_card_ubuntu-latest)
- [Windows](https://github.com/${REPO}/releases/download/${TAG_NAME}/pnp_card_windows-latest)
- [macOS](https://github.com/${REPO}/releases/download/${TAG_NAME}/pnp_card_macos-latest)

## Usage

To run the program, you need to provide two arguments:

1. **Path to the image directory**: The directory where the card images are stored.
2. **Output PDF name**: The name of the generated PDF file.

### Example Execution

\`\`\`bash
./pnp_card /path/to/directory cards.pdf
\`\`\`

## Directory Structure

\`\`\`
/path/to/directory/
├── 1_front.png
├── 1_back.jpg
├── 2_front.jpeg
├── global_back.png
\`\`\`

### Specific Scenarios
1. If 1_front.png exists but 1_back.jpg is missing, the program will use global_back.png as the back image for that card.
2. If a back image (name_back) exists without a corresponding front image (name_front), the program will throw an error indicating the issue.

EOF