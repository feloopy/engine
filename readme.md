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

<summary> Why the "Windows Protected Your PC" Warning Appears and a Quick Fix </summary>

<br>



Since FelooPy Engine is currently built using PyInstaller, which packages Python files into an executable, Windows Defender or SmartScreen may show a "Windows Protected Your PC" warning. This occurs because the executable is currently digitally unsigned, and Windows treats unsigned or unfamiliar applications—especially new ones—as potential risks, even if the app is safe to run. You might refer to [Pyinstaller's official repository](https://github.com/pyinstaller/pyinstaller/issues) for more information.


To bypass the "false-positive" warning, click "More info" and then select "Run anyway," as shown in the images below:

<div style="text-align: center;">
  <img src="./repo/assets/smart-screen.png" alt="Windows SmartScreen Warning" />
</div>

<div style="text-align: center;">
  <img src="./repo/assets/run-anyway.png" alt="Run Anyway Option" />
</div>

</details>

