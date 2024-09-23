<div align="center">
  <p>
    <a href="https://feloopy.github.io" target="_blank">
      <picture>
        <source media="(prefers-color-scheme: light)" srcset="https://github.com/feloopy/engine/raw/main/repo/assets/feloopy-engine-logo-light.png">
        <source media="(prefers-color-scheme: dark)"  srcset="https://github.com/feloopy/engine/raw/main/repo/assets/feloopy-engine-logo-dark.png">
        <img alt="FelooPy Engine's logo." src="https://github.com/feloopy/engine/raw/main/repo/assets/feloopy-engine-logo-light.png" width="300" height="auto">
      </picture>
    </a>
  </p>
</div>

<p align="center">
  <strong>Enhanced FelooPy installation and management experience</strong>
</p>

<br>
<br>

<div style="text-align: center;">
  <img src="./repo/assets/first-frame.png" alt="First Frame" />
</div>

<br>


<br>


<details>

<summary> <b> Why the "Windows Protected Your PC" Warning Appears and a Quick Fix </b> </summary>

<br>



Since FelooPy Engine is currently built using PyInstaller, which packages Python files into an executable, Windows Defender or SmartScreen may show a "Windows Protected Your PC" warning. This occurs because Windows 10 and above now treats unsigned or unfamiliar applications—especially new ones—as potential risks, even if the app is safe to run. You might refer to [Pyinstaller's official repository](https://github.com/pyinstaller/pyinstaller/issues) for more information.

To bypass the "false-positive" warning, click "More info" and then select "Run anyway," as shown in the images below:

<div style="text-align: center;">
  <img src="./repo/assets/smart-screen.png" alt="Windows SmartScreen Warning" />
</div>

<div style="text-align: center;">
  <img src="./repo/assets/run-anyway.png" alt="Run Anyway Option" />
</div>

</details>

<br>
<br>

#### Usage
The next frame will display the user agreement page:

<div style="text-align: center;"> <img src="./repo/assets/second-frame.png" alt="Second Frame" /> </div>
Next, you will see the installation mode page. If you are installing Python and FelooPy for the first time, the easy install method may be suitable. Otherwise, please use the advanced install mode.

<div style="text-align: center;"> <img src="./repo/assets/third-frame.png" alt="Third Frame" /> </div>
In the following frame, you will have two options: use an existing python.exe file on your system or download and install a new Python version, which you can select from available versions or enter manually. The default installation directory for Python can be changed if needed.

<div style="text-align: center;"> <img src="./repo/assets/fourth-frame.png" alt="Fourth Frame" /> </div>
Next, you will choose between using an existing virtual environment or creating a new one. If you have a virtual environment folder (e.g., flp-310), select that directory and enter the folder name. If not, create a new virtual environment in your preferred directory with your chosen name.

<div style="text-align: center;"> <img src="./repo/assets/fifth-frame.png" alt="Fifth Frame" /> </div>
Then, select the version of the FelooPy package to install, along with its variant. Optional features allow you to install additional packages from PyPI, enabling integration with some commercial or extra packages.

<div style="text-align: center;"> <img src="./repo/assets/sixth-frame.png" alt="Sixth Frame" /> </div>
On the following page, you’ll get an overview of the actions that will be taken, along with notes and information on commands and directories.

<div style="text-align: center;"> <img src="./repo/assets/seventh-frame.png" alt="Seventh Frame" /> </div>
The installation progress will then begin. This process may take some time, depending on your internet speed and system specifications.

<div style="text-align: center;"> <img src="./repo/assets/eighth-frame.png" alt="Eighth Frame" /> </div>
Once the process is complete, you'll receive additional information and the path to the virtual environment where FelooPy is installed. Ensure that this path is included in your PATH environment variable. If not, you may need to rerun the process with administrator rights or do it manually.

<div style="text-align: center;"> <img src="./repo/assets/final-frame.png" alt="Final Frame" /> </div>
Thank you for using and supporting FelooPy!