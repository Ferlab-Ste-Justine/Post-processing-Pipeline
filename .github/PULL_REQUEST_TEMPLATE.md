<!--
# ferlab/postprocessing pull request

Many thanks for contributing to ferlab/postprocessing!

Please fill in the appropriate checklist below (delete whatever is not relevant).
Since this repository is in construction, some of the points below regarding tests and linter might not apply yet. Make sure
to do the maximum possible.  For now, the tests are performed manually. Add a description of your tests in your pull request.
You can ask help on the [#bioinfo](https://cr-ste-justine.slack.com/archives/C074VMACUD9slack) channel.
These are the most common things requested on pull requests (PRs).
-->

## PR checklist

- [ ] This comment contains a description of changes (with reason).
- [ ] If you've fixed a bug or added code that should be tested, add tests!
- [ ] If you've added a new tool - have you followed the pipeline conventions in the [contribution docs](https://github.com/ferlab/postprocessing/tree/master/.github/CONTRIBUTING.md)
- [ ] Make sure your code lints (`nf-core lint`).
- [ ] Ensure the test suite passes (`nextflow run . -profile test,docker --outdir <OUTDIR>`).
- [ ] Check for unexpected warnings in debug mode (`nextflow run . -profile debug,test,docker --outdir <OUTDIR>`).
- [ ] Usage Documentation in `docs/usage.md` is updated.
- [ ] Output Documentation in `docs/output.md` is updated.
- [ ] Reference Data Documentation in `docs/reference_data.md` is updated.
- [ ] `CHANGELOG.md` is updated.
- [ ] `README.md` is updated (including new tool citations and authors/contributors).
