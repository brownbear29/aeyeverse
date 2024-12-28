const imageFolder = 'images'; // Folder where your images are stored
const totalImages = 80; // Total number of images in the folder
const imageGrid = document.getElementById('imageGrid');

// Dynamically generate image elements
for (let i = 1; i <= totalImages; i++) {
    const img = document.createElement('img');

    // Check if the current image number should use the .gif extension
    if (i === 11 || i === 14 || i === 70) {
        img.src = `${imageFolder}/${i}.gif`;
    } else {
        img.src = `${imageFolder}/${i}.jpg`;
    }
    img.src = `${imageFolder}/${i}.png`;
    img.alt = `Image ${i}`;
    imageGrid.appendChild(img);
}