## Reporting bugs

Bug reports and feature requests for 4chan X are tracked at **https://github.com/ccd0/4chan-x/issues**.

You can submit a bug report / feature request either via your Github account or the [anonymous report form](https://gitreports.com/issue/ccd0/4chan-x).

If you're reporting a bug, the more detail you can give, the better. If I can't reproduce your bug, I probably won't be able to fix it. You can help by doing the following:

1. Include precise steps to reproduce the problem, with the expected and actual results.
2. Make sure your **browser**, **4chan X**, and (if applicable) **Greasemonkey** are up to date. Include the versions you're using in bug reports.
3. Test if the bug occurs with 4chan X disabled and using the native extension. If it does, it's likely a problem with 4chan or your browser rather than with 4chan X.
4. Open your console with Shift+Control+J (⇧⌘J on OS X Firefox, ⌘⌥J on OS X Chromium), and look for any error messages, especially ones that occur at the same time as the bug. Include these in your bug report. If you're using Firefox, be sure to check the browser console (Shift+Control+J), not the web console (Shift+Control+K) as errors may not show up in the latter.
5. To test if the bug occurs under the default settings or only with specific settings, back up your settings and reset them using the **Export** and **Reset Settings** links in the settings panel. If the bug only occurs under specific settings, upload your exported settings to a site like https://paste.installgentoo.com/, and link to it in your bug report. If your settings contains sensitive information (e.g. personas), edit the text file manually.
6. To check if a bug is due to a conflict with another extension, temporarily disable any other extensions and userscripts. If the bug goes away, turn them back on one by one until you find the one causing the problem.

## Development & Contribution

### Get started

- Install [node.js](http://nodejs.org/).
- Install [Grunt's CLI](http://gruntjs.com/): `npm install -g grunt-cli`
- Clone 4chan X: `git clone https://github.com/ccd0/4chan-x.git`
- Open the directory: `cd 4chan-x`
- Install/Update 4chan X dependencies: `npm install`

### Build

- Build with `grunt`.
- You can continuously build with `grunt watch`.

### Contribute

- Edit the sources (not the compiled scripts in the builds/ directory).
- Compile the script with `grunt`.
- Install the compiled script (found in the testbuilds/ directory), and test your changes.
- Open a pull request by doing any of the following:
  - Fork this repository on Github, push your changes to your fork, and make a pull request via Github's mechanism.
  - Push your changes to any online Git repository, and [open an issue](https://gitreports.com/issue/ccd0/4chan-x) with an explanation of your changes and the URL, branch, and commit you want me to pull from.
  - Export your changes via `git bundle` (e.g. `git bundle create file.bundle master..your-branch`), and upload them to a file host like https://jii.moe/. Then [open an issue](https://gitreports.com/issue/ccd0/4chan-x) with an explanation of your changes and the URL of the file.

Archive list updates should go to https://github.com/MayhemYDG/archives.json.
