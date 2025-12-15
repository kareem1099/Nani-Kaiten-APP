import os
import torch
import random
import numpy as np
from PIL import Image
from tqdm import tqdm
import torch.nn.functional as F
import torchvision.transforms as T
import torchvision.transforms.functional as TF
from torch.utils.data import Dataset, DataLoader
from torchvision.models.segmentation import deeplabv3_resnet101

# ====== CONFIG ======
train_dir = "D:/BEDSSS/kaiten55.v3i.png-mask-semantic/train"
valid_dir = "D:/BEDSSS/kaiten55.v3i.png-mask-semantic/valid"
num_classes = 2
batch_size =4
epochs = 100
lr = 3e-3
patience = 15
image_size = (512, 512)  # Optimal size for performance
log_dir = "runs/experiment_1"  # For TensorBoard

# ====== Enhanced Transformations ======
class JointTransform:
    def __init__(self, augment=True):
        self.augment = augment
        self.size = image_size

    def __call__(self, image, mask):
        # Resize with optimal interpolation
        image = TF.resize(image, self.size, interpolation=Image.BILINEAR)
        mask = TF.resize(mask, self.size, interpolation=Image.NEAREST)

        if self.augment:
            # Geometric transformations
            if random.random() > 0.5:
                image = TF.hflip(image)
                mask = TF.hflip(mask)
            
            angle = random.uniform(-30, 30)
            image = TF.rotate(image, angle)
            mask = TF.rotate(mask, angle, interpolation=Image.NEAREST)
            
            # Photometric transformations
            brightness = random.uniform(0.8, 1.2)
            contrast = random.uniform(0.8, 1.2)
            image = TF.adjust_brightness(image, brightness)
            image = TF.adjust_contrast(image, contrast)

            # Advanced augmentations
            if random.random() > 0.7:
                sigma = random.uniform(0.1, 2.0)
                image = TF.gaussian_blur(image, kernel_size=[5, 5], sigma=[sigma, sigma])

        # Convert to tensor and normalize
        image = TF.to_tensor(image)
        mask_np = np.array(mask)
        
        # Advanced mask processing
        if mask_np.max() <= 1:
            mask_np = mask_np.astype(np.uint8)
        else:
            mask_np = (mask_np > 127).astype(np.uint8)  # Dynamic thresholding

        mask = torch.from_numpy(mask_np).long()
        return image, mask

# ====== Dataset Class with Validation ======
class SegmentationDataset(Dataset):
    def __init__(self, folder_path, transform=None):
        self.images = sorted([
            f for f in os.listdir(folder_path)
            if (f.endswith(".jpg") or f.endswith(".png")) and "_mask" not in f
        ])
        self.folder_path = folder_path
        self.transform = transform

    def __len__(self):
        return len(self.images)

    def __getitem__(self, idx):
     img_name = self.images[idx]
    
    # تجاهل صورة معينة بالاسم لو سببت مشاكل
     if "Runway-2023-09-28T14_46_56-723Z" in img_name:
        return self.__getitem__((idx + 1) % len(self))

     img_path = os.path.join(self.folder_path, img_name)

     if img_name.endswith(".jpg"):
        base_name = img_name[:-4]
     elif img_name.endswith(".jpeg"):
        base_name = img_name[:-5]
     elif img_name.endswith(".png"):
        base_name = img_name[:-4]
     else:
        base_name = img_name

     mask_name = base_name + "_mask.png"
     mask_path = os.path.join(self.folder_path, mask_name)

     image = Image.open(img_path).convert("RGB")
     mask = Image.open(mask_path).convert("L")

     if self.transform:
        image, mask = self.transform(image, mask)

        # Validate mask values
        mask_np = np.array(mask)
        unique_values = np.unique(mask_np)
        assert set(unique_values).issubset({0, 1}), f"Invalid mask values: {unique_values}"
        print(unique_values)

     return image, mask

# ====== Advanced Model Initialization with ResNet101 ======
def initialize_model():
    model = deeplabv3_resnet101(pretrained=True)
    
    # Partial freezing (first 50 layers)
    for i, (name, param) in enumerate(model.backbone.named_parameters()):
        if i < 50:
            param.requires_grad = False
    
    # Enhanced classifier
    model.classifier[4] = torch.nn.Sequential(
        torch.nn.Conv2d(256, 128, kernel_size=3, padding=1),
        torch.nn.BatchNorm2d(128),
        torch.nn.ReLU(),
        torch.nn.Conv2d(128, num_classes, kernel_size=1)
    )
    
    # Improved aux classifier
    if hasattr(model, 'aux_classifier') and model.aux_classifier is not None:
        model.aux_classifier[4] = torch.nn.Conv2d(256, num_classes, kernel_size=1)
    
    return model

# ====== Loss Functions ======
class CombinedLoss(torch.nn.Module):
    def __init__(self, weight=None):
        super().__init__()
        self.ce_loss = torch.nn.CrossEntropyLoss(weight=weight)
        
    def forward(self, preds, targets):
        ce = self.ce_loss(preds, targets)
        
        # Dice loss calculation
        probs = torch.softmax(preds, dim=1)
        dice_target = F.one_hot(targets, num_classes).permute(0, 3, 1, 2).float()
        smooth = 1.0
        
        intersection = torch.sum(probs * dice_target, dim=(2, 3))
        union = torch.sum(probs + dice_target, dim=(2, 3))
        dice = 1 - (2 * intersection + smooth) / (union + smooth)
        dice = dice.mean()
        
        return 0.7 * ce + 0.3 * dice

# ====== Metrics ======
def calculate_metrics(preds, masks):
    preds = preds.detach().cpu()
    masks = masks.detach().cpu()
    
    # Per-class IoU
    iou_per_class = []
    for cls in range(num_classes):
        pred_cls = (preds == cls)
        target_cls = (masks == cls)
        
        intersection = (pred_cls & target_cls).float().sum((1, 2))
        union = (pred_cls | target_cls).float().sum((1, 2))
        
        iou = (intersection + 1e-7) / (union + 1e-7)
        iou_per_class.append(iou.mean().item())
    
    # Overall accuracy
    accuracy = (preds == masks).float().mean()
    
    return sum(iou_per_class)/num_classes, accuracy.item(), iou_per_class[1]

# ====== Training Loop ======
if __name__ == "__main__":
    # Initialize
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    
    # Data
    train_dataset = SegmentationDataset(train_dir, transform=JointTransform(augment=True))
    valid_dataset = SegmentationDataset(valid_dir, transform=JointTransform(augment=False))
    
    train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True,
                            num_workers=4, pin_memory=True, drop_last=True)
    valid_loader = DataLoader(valid_dataset, batch_size=batch_size, shuffle=False,
                            num_workers=4, pin_memory=True, drop_last=False)
    
    # Model
    model = initialize_model().to(device)
    
    # Optimizer with differential learning rates
    optimizer = torch.optim.AdamW([
        {'params': model.backbone.parameters(), 'lr': lr/10},
        {'params': model.classifier.parameters(), 'lr': lr},
        {'params': model.aux_classifier.parameters(), 'lr': lr} if hasattr(model, 'aux_classifier') else []
    ], lr=lr, weight_decay=1e-4)
    
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
        optimizer, mode='max', factor=0.5, patience=5, verbose=True
    )
    
    criterion = CombinedLoss(weight=torch.tensor([1.0, 3.0]).to(device))  # Higher weight for foreground
    
    # Training
    best_iou = 0.0
    no_improve_epochs = 0
    
    for epoch in range(epochs):
        model.train()
        epoch_loss = 0
        
        # Training phases
        train_loop = tqdm(train_loader, desc=f"Epoch {epoch+1}/{epochs} [Train]", unit="batch")
        for imgs, masks in train_loop:
            imgs, masks = imgs.to(device), masks.to(device)
            
            outputs = model(imgs)
            loss = criterion(outputs["out"], masks)
            
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
            
            epoch_loss += loss.item()
            train_loop.set_postfix(loss=loss.item())
        
        avg_train_loss = epoch_loss / len(train_loader)
        
        # Validation phase
        model.eval()
        val_iou, val_acc, val_iou_foreground = 0, 0, 0
        with torch.no_grad():
            for imgs, masks in valid_loader:
                imgs, masks = imgs.to(device), masks.to(device)
                
                if imgs.size(0) == 1:  # Skip last batch if size=1
                    continue
                
                outputs = model(imgs)
                preds = torch.argmax(outputs["out"], dim=1)
                
                batch_iou, batch_acc, batch_iou_fg = calculate_metrics(preds, masks)
                val_iou += batch_iou
                val_acc += batch_acc
                val_iou_foreground += batch_iou_fg
        
        val_iou /= len(valid_loader)
        val_acc /= len(valid_loader)
        val_iou_foreground /= len(valid_loader)
        
        print(f"\n Epoch {epoch+1} Results:")
        print(f"Train Loss: {avg_train_loss:.4f} | Val IoU: {val_iou:.4f}")
        print(f"Val Foreground IoU: {val_iou_foreground:.4f} | Val Acc: {val_acc:.4f}")
        
        # Early stopping and model saving
        if val_iou_foreground > best_iou:
            best_iou = val_iou_foreground
            no_improve_epochs = 0
            torch.save(model.state_dict(), "Final_best_model.pth")
            print(f" Saved best model with IoU: {best_iou:.4f}")
        else:
            no_improve_epochs += 1
            print(f" No improvement for {no_improve_epochs}/{patience} epochs")
        
        scheduler.step(val_iou_foreground)
        
        if no_improve_epochs >= patience:
            print(f" Early stopping triggered at epoch {epoch+1}")
            break
    
    print(f"\n Training complete! Best Foreground IoU: {best_iou:.4f}")
