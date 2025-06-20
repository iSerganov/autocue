# autocue.cue_file.liq
# 2024-04-10 - Moonbase59
# 2024-04-12 - Toots: re-organize to integrate as core autocue implementation.
# 2024-04-12 - Moonbase59 - re-introduce `liq_duration` as `liq_cue_duration`.
# 2024-04-19 - Moonbase59 - rename to "autocue.cue_file.liq"
#                         - update to use same `cue_file` as master branch
# 2024-04-20 - Moonbase59 - allow floats as loudness values
# 2024-04-24 - Moonbase59 - rework to follow same logic as autocue2
# 2024-04-25 - Moonbase59 - handle old RG1/mp3gain positive loudness reference
#                         - add nice option (+10) for Linux users
# 2024-04-30 - Toots & Moonbase59 - Fix extra_metadata bug, make these optional
#                                   replaygain_track_gain,
#                                   replaygain_reference_loudness
# 2024-05-02 - Moonbase59 - add clipping prevention logic (cue_file -k)
# 2024-05-04 - Moonbase59 - Add (informational) liq_loudness_range
# 2024-06-04 - Moonbase59 - v2.0.0 Breaking: Add -r/--replaygain overwrite
#                         - Changed `liq_true_peak` to `liq_true_peak_db`,
#                           add new `liq_true_peak` (linear, like RG)
# 2024-06-05 - Moonbase59 - v2.0.2 Initial display of version, at log level 2.
# 2024-06-08 - Moonbase59 - v2.0.3 Sync version number with cue_file
# 2024-06-09 - Moonbase59 - v2.1.0 Sync version number with cue_file
# 2024-06-11 - Moonbase59 - v2.2.0 JSON override tags for cue_file in temp file:
#                           Allows passing annotate/database overrides to
#                           cue_file, to reduce re-analysis runs even more.
# 2024-06-11 - Moonbase59 - v2.2.1 Make JSON override switchable
# 2024-06-11 - Moonbase59 - v3.0.0 Add variable blankskip (0.0=off)
#                         - BREAKING: `liq_blankskip` now flot, not bool anymore!
#                           Pre-v3.0.0 tags will be read graciously.
# 2024-06-12 - Moonbase59 - v3.0.1 Increase default min. silence to 5.0 s
# 2024-06-13 - Moonbase59 - v4.0.0 Add `liq_sustained_ending`,
#                           something_to_float() for old `liq_blankskip` tags.
#                         - Add `-d` to cue_file call
# 2024-06-14 - Moonbase59 - Add external `cue_file` version check and a
#                           `check_autocue_setup` function to be used after
#                           the user-defined settings.
# 2024-06-15 - Moonbase59 - v4.0.1 - Sync with cue_file version
# 2024-06-16 - Moonbase59 - v4.0.2 - Allow `-8.33dB` type values with no blank
# 2024-06-18 - Moonbase59 - v4.0.3 - Changed overlay_longtail from -15 to -12,
#                           most people seem to want transitions a bit tighter
# 2024-07-01 - Moonbase59 - v4.0.4 - Sync with cue_file version
# 2024-07-02 - Moonbase59 - v4.0.5 - Sync with cue_file version
# 2024-07-04 - Moonbase59 - v4.0.6 - Make duration non-overridable, i.e.,
#                           it’s ALWAYS taken from the cue_file result.
# 2024-07-05 - Moonbase59 - v4.1.0 - New `liq_cue_file handling, allows to
#                           ignore overrides for cue_file data if true. This is
#                           mainly for fast-changing files like news or time,
#                           for which LS/AzuraCast might not yet have updated
#                           the metadata.
#                           - not set = default (metadata can override cue_file)
#                           - false = don’t autocue (still use metadata if present)
#                           - true = cue_file results override metadata
# 2024-08-05 - Moonbase59 - v4.1.1 Sync with cue_file version
# 2024-12-19 - iSerganov  - v4.2.0 Liquidsoap 2.3.0 compatibility
# 2025-06-17 - iSerganov  - v4.2.1 Checking enforce_start_time tag and setting liq_cue_in accordingly

# Lots of debugging output for AzuraCast in this, will be removed eventually.

# --- Copy-paste Azuracast LS Config, second input box BEGIN ---

# Initialize settings for cue_file autocue implementation
let settings.autocue.cue_file = ()

# Internal only! Not a user setting.
let settings.autocue.cue_file.version =
  settings.make(
    description=
      "Software version of autocue.cue_file. Should coincide with `cue_file`.",
    "4.2.1"
  )

# Internal only! Not a user setting.
let settings.autocue.cue_file.version_external =
  settings.make(
    description=
      "Software version of external `cue_file`.",
    "(unknown)"
  )

let settings.autocue.cue_file.path =
  settings.make(
    description=
      "Path of the cue_file binary.",
    "cue_file"
  )

let settings.autocue.cue_file.fade_in =
  settings.make(
    description=
      "Default fade-in duration if not specified by the user.",
    0.1
  )

let settings.autocue.cue_file.fade_out =
  settings.make(
    description=
      "Default fade-out duration if not specified by the user.",
    2.5
  )

let settings.autocue.cue_file.timeout =
  settings.make(
    description=
      "Timeout (in seconds) for cue_file executions.",
    60.0
  )

let settings.autocue.cue_file.target =
  settings.make(
    description=
      "Loudness target in LUFS.",
    -18.0
  )

let settings.autocue.cue_file.silence =
  settings.make(
    description=
      "Silence level (for cue points) in LU below track loudness.",
    -42.0
  )

let settings.autocue.cue_file.overlay =
  settings.make(
    description=
      "Start overlay level in LU below track loudness.",
    -8.0
  )

let settings.autocue.cue_file.longtail =
  settings.make(
    description=
      "More than so many seconds of calculated overlay are considered a long \
       tail.",
    15.0
  )

let settings.autocue.cue_file.overlay_longtail =
  settings.make(
    description=
      "Extra LU level below overlay loudness, to recalculate songs with long \
       tails.",
    -12.0
  )

let settings.autocue.cue_file.sustained_loudness_drop =
  settings.make(
    description=
      "Consider track to have a sustained ending if its loudness at the end \
      does NOT drop more than so many percent. Otherwise, it has a hard ending.",
    40.0
  )

let settings.autocue.cue_file.noclip =
  settings.make(
    description=
      "Clipping prevention: Lowers track gain if needed, to avoid peaks \
       going above -1 dBFS. Uses true peak values of all audio channels.",
    false
  )

let settings.autocue.cue_file.blankskip =
  settings.make(
    description=
      "Skip blank (silence) within track if longer than `blankskip` seconds \
       (get rid of \"hidden tracks\"). \
       Sets the cue-out point to where the silence begins. Don't use this \
       with spoken or TTS-generated text, as it will often cut the message \
       short. Zero (0.0) to switch off.",
    0.0
  )

let settings.autocue.cue_file.unify_loudness_correction =
  settings.make(
    description=
      'Unify `replaygain_track_gain` and `liq_amplify`. If enabled, this will \
       ensure both have the same value, with `replaygain_track_gain` taking \
       precedence if seen, and we have a `replaygain_reference_loudness`. \
       Allows scripts to amplify on either value, without loudness jumps.',
    true
  )

let settings.autocue.cue_file.write_tags =
  settings.make(
    description=
      "Write back `liq_*` tags to original audio file. Ensure you have enough \
       free space to hold a copy of the original file.",
    false
  )

let settings.autocue.cue_file.write_replaygain =
  settings.make(
    description=
      "Write ReplayGain tags to file (track only, no album). Useful if your \
       files have no previous RG tags. Only valid if `write_tags` is also true.",
    false
  )

let settings.autocue.cue_file.force_analysis =
  settings.make(
    description=
      'Force re-analysis even when all needed data could be read from file tags.',
    false
  )

let settings.autocue.cue_file.nice =
  settings.make(
    description=
      'Linux/MacOS only: Use nice for `cue_file` operations?',
    false
  )

let settings.autocue.cue_file.use_json_metadata =
  settings.make(
    description=
      'Send metadata to `cue_file` as JSON, allowing to override/add to \
       autocue-relevant metadata stored in file tags. This can help to avoid \
       unnecessary re-analysis runs.',
    true
  )

let settings.autocue.cue_file.ignored_overrides =
  settings.make(
    description=
      'List of cue_file results that cannot be overridden by existing \
       metadata or annotations. One such field is `duration`, as it is not \
       a tag, and determined otherwise.',
    ['duration']
  )


time_to_skip = ref(0.0)
stdlib_metadata = metadata

# metadata.json.stringify only exports a limited set, use our own
def meta_json_stringify(
  ~compact=false,
  ~json5=false,
  m
) =
  m = metadata.cover.remove(m)
  data = json()
  list.iter(fun (v) -> data.add(fst(v), snd(v)), m)
  json.stringify(json5=json5, compact=compact, data)
end

# Need to handle pre-version 3.0.0 `liq_blankskip`: was bool, is now float`
# @vitoyucepi, in: https://github.com/savonet/liquidsoap/discussions/3965#discussioncomment-9744430
def something_to_float(~true_value=1., value) =
  value_string = string.case(string(value))
  possible_float =
    try
      float_of_string(value_string)
    catch _ do
      null()
    end
  possible_bool =
    try
      bool_of_string(value_string) ? true_value : 0.
    catch _ do
      null()
    end
  (possible_float ?? possible_bool) ?? 0.
end

# Deconstruct a SemVer version, return a record
def semver(s) =
  s = null.get(default="", s)
  # SemVer RegEx, see https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
  #r = r/(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$/gm
  r = r/(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*)(?:-(?<prerelease>(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+(?<build>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$/gm
  v = r.exec(s)
  #print(v)
  {
    version = v[0],
    major = v.groups["major"],
    minor = v.groups["minor"],
    patch = v.groups["patch"],
    prerelease = v.groups["prerelease"],
    build = v.groups["build"]
  }
end

# Compare two SemVers
# The return value is negative if ver1 < ver2,
# zero if ver1 == ver2 and strictly positive if ver1 > ver2
def semver_compare(s1, s2) =
  s1 = null.get(default="", s1)
  s2 = null.get(default="", s2)
  v1 = semver(s1)
  v2 = semver(s2)

  if v1.major == v2.major and v1.minor == v2.minor and v1.patch == v2.patch then
    0
  elsif v1.major > v2.major then
    1
  elsif v1.major >= v2.major and v1.minor > v2.minor then
    1
  elsif v1.major >= v2.major and v1.minor >= v2.minor and v1.patch > v2.patch then
    1
  else
    -1
  end
end

# Get version of a CLI command
def file_semver(command) =
  res =
    list.hd(
      default="",
      process.read.lines(
        #timeout=2.,
        command ^ " --version"
      )
    )
  semver(res)
end

# Check Autocue setup, shutdown if desired, print to terminal if desired
stdlib_shutdown = shutdown
stdlib_print = print

def check_autocue_setup(~shutdown=false, ~print=false) =
  settings.autocue.cue_file.version_external := file_semver(settings.autocue.cue_file.path()).version

  if semver_compare(
    settings.autocue.cue_file.version(),
    settings.autocue.cue_file.version_external()
  ) == 0
  then
    # set this so annotations (priority 5) can still override autocue values
    settings.autocue.metadata.priority := 10
    settings.autocue.preferred := "cue_file"
    # use our values in any case
    settings.autocue.amplify_behavior := "keep"
    # avoid dead air from reconcile, reset default 3.0s to our fade_out duration
    settings.fade.out.duration := settings.autocue.cue_file.fade_out()
    # Let user know what version (s)he is running
    log(level=2, label="autocue.cue_file",
      'You are using autocue.cue_file version \
       #{settings.autocue.cue_file.version()}.'
    )
    log(level=2, label="autocue.cue_file",
      'The external "#{settings.autocue.cue_file.path()}" \
       is version #{settings.autocue.cue_file.version_external()}'
    )
    log(level=2, label="autocue.cue_file",
      'Setting `settings.fade.out.duration` to \
       #{settings.autocue.cue_file.fade_out()} s, from \
       `settings.autocue.cue_file.fade_out`.'
    )
    if print then
      stdlib_print(
        'You are using autocue.cue_file version \
         #{settings.autocue.cue_file.version()}.'
      )
      stdlib_print(
        'The external "#{settings.autocue.cue_file.path()}" \
         is version #{settings.autocue.cue_file.version_external()}'
      )
      stdlib_print(
        'Setting `settings.fade.out.duration` to \
         #{settings.autocue.cue_file.fade_out()} s, from \
         `settings.autocue.cue_file.fade_out`.'
      )
    end
    true
  else
    log(level=1, label="autocue.cue_file",
      'ERROR: autocue.cue_file v#{settings.autocue.cue_file.version()} \
       doesn’t match external "#{settings.autocue.cue_file.path()}" \
       v#{settings.autocue.cue_file.version_external()}!\n\
       Autocue NOT ACTIVATED!'
    )
    # repeat on console, so standalone can see it
    if print then
      stdlib_print(
        'ERROR: autocue.cue_file v#{settings.autocue.cue_file.version()} \
         doesn’t match external "#{settings.autocue.cue_file.path()}" \
         v#{settings.autocue.cue_file.version_external()}!\n\
         Autocue NOT ACTIVATED!'
      )
    end
    if shutdown then
      log(level=1, label="autocue.cue_file", "Shutting down...")
      if print then stdlib_print("Shutting down...") end
      stdlib_shutdown(code=2)
    end
    false
  end
end


# Compute cue_file data
# @flag extra
def cue_file(~request_metadata, ~file_metadata, filename) =
  timeout = settings.autocue.cue_file.timeout()
  target = settings.autocue.cue_file.target()
  silence = settings.autocue.cue_file.silence()
  overlay = settings.autocue.cue_file.overlay()
  longtail = settings.autocue.cue_file.longtail()
  overlay_longtail = settings.autocue.cue_file.overlay_longtail()
  drop = settings.autocue.cue_file.sustained_loudness_drop()
  blankskip = settings.autocue.cue_file.blankskip()
  write_tags = settings.autocue.cue_file.write_tags()
  write_replaygain = settings.autocue.cue_file.write_replaygain()
  force_analysis = settings.autocue.cue_file.force_analysis()
  nice = settings.autocue.cue_file.nice()
  noclip = settings.autocue.cue_file.noclip()
  use_json_metadata = settings.autocue.cue_file.use_json_metadata()

  label = "autocue.cue_file"

  # combine request & file metadata into one list, where
  # request_metadata (annotations) takes precedence
  metadata = list.fold(
    fun(res, entry) ->
      if list.assoc.mem(fst(entry), res) then
        res
      else
        [...res, entry]
      end,
      request_metadata,
      file_metadata
  )

  m = ref(metadata)

  # so we can use meta["something"]
  meta = m()

  if
    meta["liq_cue_file"] == "false"
  then
    log(
      level=2,
      label=label,
      'Skipping cue_file for "#{filename}" because liq_cue_file=false \
       forbids it.'
    )
    null()
  else
    log(
      level=3,
      label=label,
      'Now autocueing: "#{filename}"'
    )

    l = list.sort.natural(stdlib_metadata.cover.remove(meta))
    log(
      level=4,
      label=label,
      'Metadata seen for "#{filename}":'
    )
    list.iter(fun (v) -> log(level=4, label=label, "#{v}"), l)

    log(
      level=4,
      label=label,
      'liq_blankskip=#{meta["liq_blankskip"]}, songtype=#{meta["songtype"]}, \
       jingle_mode=#{meta["jingle_mode"]}'
    )

    # Blank skipping can be set globally using `settings.autocue.cue_file.blankskip`.
    # For AzuraCast, we override that setting if we detect "jingle_mode",
    # i.e. a track from a playlist that has "Hide Metadata from Listeners" set.
    # For standalone Liquidsoap, the ultimate override is `liq_blankskip`.
    # This can even be used to switch blank skipping ON if is globally off.
    blankskip = ref(blankskip)
    blankskip := list.assoc.mem("jingle_mode", meta) ? 0.0 : blankskip()

    # SAM Broadcaster compat: Switch blankskip off for all songtypes != "S"
    if list.assoc.mem("songtype", meta) then
      if meta["songtype"] != "S" then
        blankskip := 0.0
      end
    end

    # Handle annotated `liq_blankskip`, the ultimate switch
    # Pre-v3.0.0 compatibility: Check for true/false (now float)
    if list.assoc.mem("liq_blankskip", meta) then
      blankskip := null.get(
        default=0.0,
        something_to_float(
          true_value=settings.autocue.cue_file.blankskip(),
          meta["liq_blankskip"]
        )
      )
      m := list.assoc.remove("liq_blankskip", m())
      m := list.add(
        ("liq_blankskip", string.float(decimal_places=2, blankskip())),
        m()
      )
    end

    log(
      level=3,
      label=label,
      "Blank (silence) skipping active: #{blankskip() > 0.0}, set to #{blankskip()} s"
    )

    log(
      level=3,
      label=label,
      "Clipping prevention active: #{noclip}"
    )

    log(
      level=3,
      label=label,
      "Writing tags: #{write_tags}, including ReplayGain: #{write_replaygain}"
    )

    # set up CLI arguments
    args =
      ref(
        [
          '-t',
          string.float(target, decimal_places=2),
          '-s',
          string.float(silence, decimal_places=2),
          '-o',
          string.float(overlay, decimal_places=2),
          '-l',
          string.float(longtail, decimal_places=2),
          '-x',
          string.float(overlay_longtail, decimal_places=2),
          '-d',
          string.float(drop, decimal_places=2),
          filename
        ]
      )
    if noclip then args := list.add('-k', args()) end
    if blankskip() > 0.0 then
      args := ['-b', string.float(blankskip(), decimal_places=2), ...args()]
    end
    if write_tags then args := list.add('-w', args()) end
    if write_replaygain then args := list.add('-r', args()) end
    if force_analysis then args := list.add('-f', args()) end
    if nice then args := list.add('-n', args()) end

    tempfile = ref("")
    if use_json_metadata then
      # write metadata to temp file for cue_file to pick up
      tempfile := file.temp("cue_file", ".json")
      json_meta = meta_json_stringify(compact=true, m())
      log(level=4, label=label, "Writing metadata to #{tempfile()}: #{json_meta}")
      log(level=3, label=label, "Writing metadata to #{tempfile()}")
      file.write(
        data=json_meta,
        append=true,
        tempfile()
      )
      args := ['-j', tempfile(), ...args()]
    end

    res =
      try
        list.hd(
          default="",
          process.read.lines(
            timeout=timeout,
            process.quote.command(settings.autocue.cue_file.path(), args=args())
          )
        )
      catch err do
        log(
          level=2,
          label=label,
          'cue_file error: #{err}'
        )
        ""
      end

    if use_json_metadata then
      # remove tempfile again
      log(level=4, label=label, "Removing #{tempfile()}")
      file.remove(tempfile())
    end

    if list.assoc.mem("enforce_start_time", meta) then
      enforce_start_time = float_of_string(meta["enforce_start_time"], default=0.0)
      log(level=3, label=label, "Enforce start time found: #{enforce_start_time}")
      if enforce_start_time > 0.0 then
        time_to_skip := time() - enforce_start_time
      end
    end

    if
      res != ""
    then
      log(
        level=3,
        label=label,
        'cue_file result for "#{filename}": #{res}'
      )

      let json.parse (
        {
          duration,
          liq_cue_duration,
          liq_cue_in,
          liq_cue_out,
          liq_cross_start_next,
          liq_longtail,
          liq_sustained_ending,
          #liq_cross_duration,
          liq_loudness,
          liq_loudness_range,
          liq_amplify,
          liq_amplify_adjustment,
          liq_reference_loudness,
          liq_blankskip,
          liq_blank_skipped,
          liq_true_peak,
          liq_true_peak_db
        }
      :
        {
          duration: float,
          liq_cue_duration: float,
          liq_cue_in: float,
          liq_cue_out: float,
          liq_cross_start_next: float,
          liq_longtail: bool,
          liq_sustained_ending: bool,
          #liq_cross_duration: float,
          liq_loudness: string,
          liq_loudness_range: string,
          liq_amplify: string,
          liq_amplify_adjustment: string,
          liq_reference_loudness: string,
          liq_blankskip: float,
          liq_blank_skipped: bool,
          liq_true_peak: float,
          liq_true_peak_db: string
        }
      ) = res

      # must stringify, because metadata & annotations are strings
      result = ref(
        [
          ("duration", string(duration)),
          ("liq_cue_duration", string(liq_cue_duration)),
          ("liq_cue_in", string(liq_cue_in)),
          ("liq_cue_out", string(liq_cue_out)),
          ("liq_cross_start_next", string(liq_cross_start_next)),
          ("liq_longtail", string(liq_longtail)),
          ("liq_sustained_ending", string(liq_sustained_ending)),
          #("liq_cross_duration", string(liq_cross_duration)),
          ("liq_loudness", liq_loudness),
          ("liq_loudness_range", liq_loudness_range),
          ("liq_amplify", liq_amplify),
          ("liq_amplify_adjustment", liq_amplify_adjustment),
          ("liq_reference_loudness", liq_reference_loudness),
          ("liq_blankskip", string(liq_blankskip)),
          ("liq_blank_skipped", string(liq_blank_skipped)),
          ("liq_true_peak", string(liq_true_peak)),
          ("liq_true_peak_db", liq_true_peak_db)
        ]
      )

      # Check if we need to enforce the start time of the track
      if time_to_skip() > 0.0 then
        result := list.assoc.remove("liq_cue_in", result())
        if time_to_skip() >= duration then
          log(level=3, label=label, "Time to skip is greater than duration, skipping...")
          time_to_skip := time_to_skip() - duration
          result := list.add(("liq_cue_in", string.float(decimal_places=2, duration)), result())
        else
          log(level=3, label=label, "Time to skip is less than duration, setting liq_cue_in to: #{time_to_skip()}")
          result := list.add(("liq_cue_in", string.float(decimal_places=2, time_to_skip())), result())
          time_to_skip := 0.0
        end
      end

      # `liq_cue_file` determines what happens now:
      #   tag absent - normal handling, existing metadata preferred
      #   false - we'll never arrive here (don’t process, use existing metadata)
      #   true - cue_file metadata preferred (for news, time, etc.)

      if meta["liq_cue_file"] == "" then
        # no `liq_cue_file`, existing metadata preferred
        log(
          level=4,
          label=label,
          'Existing metadata can override cue_file results \
           (default; no liq_cue_file seen).'
        )
        result := list.fold(
          fun(res, entry) ->
            if list.assoc.mem(fst(entry), res) then
              if list.mem(fst(entry), settings.autocue.cue_file.ignored_overrides()) then
                [...list.assoc.remove(fst(entry), res), entry]  # take cue_file result
              else
                res  # take existing metadata (meta)
              end
            else
              [...res, entry]  # append new metadata (cue_file)
            end,
          m(),
          result()
        )
      elsif meta["liq_cue_file"] == "true" then
        # `liq_cue_file=true`, cue_file metadata preferred
        log(
          level=3,
          label=label,
          'cue_file results override existing metadata \
           because liq_cue_file=true tells us to.'
        )
        result := list.fold(
          fun(res, entry) ->
            if list.assoc.mem(fst(entry), res) then
              res  # take existing metadata (cue_file)
            else
              [...res, entry]  # append new metadata (meta)
            end,
          result(),
          m()
        )
      end

      # make a suffixed string a float
      def make_float(s) =
        # find first number, make float & return
        r = r/[+-]?\d*\.?\d+/g.exec(s)
        float_of_string(default=0.0, r[0])
      end

      # Re-calculate amplify and amplify_correction, using true_peak
      def amplify_correct(target, loudness, true_peak_dB, noclip) =
        # check if we need to reduce the gain for true peaks
        loudness = make_float(loudness)
        true_peak_dB = make_float(true_peak_dB)
        amp = ref(target - loudness)
        amp_correction = ref(0.0)
        if noclip then
          max_amp = -1.0 - true_peak_dB  # difference to EBU recommended -1 dBFS
          if amp() > max_amp then
            amp_correction := max_amp - amp()
            amp := max_amp
          end
        end
        (amp(), amp_correction())
      end

      # Override liq_amplify, liq_amplify_adjustment & liq_reference_loudness,
      # using clipping prevention as requested
      # liq_loudness & liq_true_peak_db are always in the cue_file result
      let (amp, amp_correction) =
        amplify_correct(
          target,
          list.assoc("liq_loudness", result()),
          list.assoc("liq_true_peak_db", result()),
          noclip
        )
      result := list.assoc.remove("liq_amplify", result())
      result := list.add(("liq_amplify", string.float(decimal_places=2, amp) ^ " dB"), result())
      result := list.assoc.remove("liq_amplify_adjustment", result())
      result := list.add(("liq_amplify_adjustment", string.float(decimal_places=2, amp_correction) ^ " dB"), result())
      result := list.assoc.remove("liq_reference_loudness", result())
      result := list.add(("liq_reference_loudness", string.float(decimal_places=2, target) ^ " LUFS"), result())

      if settings.autocue.cue_file.unify_loudness_correction() then
        # We wish to avoid loudness jumps in all possible cases,
        # so bring `replaygain_track_gain` and `liq_amplify` in line.
        # NOTE: This also works for different loudness targets, if
        # files have been tagged with a valid replaygain_reference_loudness.
        if list.assoc.mem("replaygain_track_gain", result()) then
          if list.assoc.mem("replaygain_reference_loudness", result()) then
            la = list.assoc(default="0.00 dB", "liq_amplify", result())
            rg = list.assoc(default="0.00 dB", "replaygain_track_gain", result())
            rgf = make_float(rg)
            rgr = list.assoc(default=string.float(decimal_places=2, target)^" dB", "replaygain_reference_loudness", result())
            rgrf = ref(make_float(rgr))
            # Handle old RG1/mp3gain positive loudness reference
            # "89 dB" (SPL) should actually be -14 LUFS, but as a reference
            # it is usually set equal to the RG2 -18 LUFS reference point
            if rgrf() > 0. then rgrf := rgrf() - 107. end
            # adjust replaygain_track_gain by loudness target difference, set reference
            # we can safely do that since we NEVER write back replaygain_* tags
            # Clipping prevention wins over simple RG adjusting
            if noclip then
              # override replaygain_track_gain with already calculated liq_amplify
              result := list.assoc.remove("replaygain_track_gain", result())
              result := list.add(("replaygain_track_gain", la), result())
              rg = string.float(decimal_places=2, rgf + (target - rgrf())) ^ " dB"
              log(level=3, label=label, 'Clipping prevention: Adjusted calculated replaygain_track_gain from #{rg} to #{la}')
            else
              # simply calculate new RG
              rg = string.float(decimal_places=2, rgf + (target - rgrf())) ^ " dB"
              result := list.assoc.remove("replaygain_track_gain", result())
              result := list.add(("replaygain_track_gain", rg), result())
              # Set liq_amplify to the same value
              result := list.assoc.remove("liq_amplify", result())
              result := list.add(("liq_amplify", rg), result())
              # And reset liq_amplify_adjustment
              result := list.assoc.remove("liq_amplify_adjustment", result())
              result := list.add(("liq_amplify_adjustment", "0.00 dB"), result())
              log(level=3, label=label, 'Replaced liq_amplify=#{la} with #{rg} from adjusted replaygain_track_gain')
            end
            # set replaygain_reference_loudness to new target
            rgr = string.float(decimal_places=2, target) ^ " LUFS"
            result := list.assoc.remove("replaygain_reference_loudness", result())
            result := list.add(("replaygain_reference_loudness", rgr), result())
          else
            log(level=3, label=label, "Can't override liq_amplify from replaygain_track_gain, replaygain_reference_loudness missing.")
          end
        else
          # no `replaygain_track_gain` seen? insert one, using calculated `liq_amplify`
          rg = list.assoc(default="0.00 dB", "liq_amplify", result())
          result := list.add(("replaygain_track_gain", rg), result())
          # also insert a `replaygain_reference_loudness`
          rgr = string.float(decimal_places=2, target) ^ " LUFS"
          result := list.assoc.remove("replaygain_reference_loudness", result())
          result := list.add(("replaygain_reference_loudness", rgr), result())
          log(level=3, label=label, 'Inserted replaygain_track_gain #{rg} and replaygain_reference_loudness #{rgr}')
        end
      end

      # Show any clipping prevention adjustments
      amp_correction_dB = list.assoc(default="0.00 dB", "liq_amplify_adjustment", result())
      if noclip and amp_correction_dB != "0.00 dB" then
        log(
          level=3,
          label=label,
          'Clipping prevention: Adjusted liq_amplify by #{amp_correction_dB} \
           because track’s true peak is #{list.assoc("liq_true_peak_db", result())}.'
        )
      end

      # Adjust fades and cue-out, if necessary
      liq_cue_in = float_of_string(list.assoc("liq_cue_in", result()))
      liq_cue_out = float_of_string(list.assoc("liq_cue_out", result()))
      liq_cross_start_next = float_of_string(list.assoc("liq_cross_start_next", result()))
      liq_fade_in =
        try
          float_of_string(list.assoc("liq_fade_in", result()))
        catch _ do
          log(
            level=3,
            label=label,
            "No fade-in duration given, using default setting \
             (#{settings.autocue.cue_file.fade_in()} s)."
          )
          settings.autocue.cue_file.fade_in()
        end

      liq_fade_out =
        try
          float_of_string(list.assoc("liq_fade_out", result()))
        catch _ do
          log(
            level=3,
            label=label,
            "No fade-out duration given, using default setting \
             (#{settings.autocue.cue_file.fade_out()} s)."
          )
          settings.autocue.cue_file.fade_out()
        end

      # User might have set cue-out but not start_next, correct
      liq_cross_start_next =
        if liq_cross_start_next <= liq_cue_out
        then
          liq_cross_start_next
        else
          start_next = liq_cue_out - liq_fade_out
          if start_next > liq_cue_in
          then
            # we have enough room for the fade-out
            log(
              level=3,
              label=label,
              "Given liq_cross_start_next (#{liq_cross_start_next} s) > \
               cue-out point (#{liq_cue_out} s), set to #{start_next} s."
            )
            start_next
          else
            # not enough room for fade-out, set to cue-out
            log(
              level=3,
              label=label,
              "Given liq_cross_start_next (#{liq_cross_start_next} s) > \
               cue-out point (#{liq_cue_out} s), set to #{liq_cue_out} s."
            )
            liq_cue_out
          end
        end

      # Adjust cue_out according to user-supplied fade_out
      let (liq_fade_out, liq_cue_out) =
        if
          liq_cross_start_next + liq_fade_out < liq_cue_out
        then
          cue_out = liq_cross_start_next + liq_fade_out
          overlay_duration = liq_cue_out - liq_cross_start_next
          log(
            level=3,
            label=label,
            "Given fade-out (#{liq_fade_out} s) < \
             overlay duration (#{overlay_duration} s), moving cue-out point \
             from #{liq_cue_out} s to #{cue_out} s."
          )
          (liq_fade_out, cue_out)
        else
          fade_out = liq_cue_out - liq_cross_start_next
          log(
            level=2,
            label=label,
            "Given fade-out duration (#{liq_fade_out} s) exceeds \
             available time, using #{fade_out} s."
          )
          (fade_out, liq_cue_out)
        end

      # Check for invalid fade.in
      let liq_fade_in =
        if
          liq_fade_in < liq_cue_out - liq_cue_in
        then
          liq_fade_in
        else
          log(
            level=2,
            label=label,
            "Given fade-in duration (#{liq_fade_in} s) exceeds \
             available time, using 0.1 s."
          )
          0.1
        end

      # correct `liq_cue_duration`
      liq_cue_duration = liq_cue_out - liq_cue_in
      result := list.assoc.remove("liq_cue_duration", result())
      result := list.add(("liq_cue_duration",
        string.float(decimal_places=2, liq_cue_duration)), result())

      # Update result
      result := list.assoc.remove("liq_cue_out", result())
      result := list.add(("liq_cue_out", string(liq_cue_out)), result())
      result := list.assoc.remove("liq_cross_start_next", result())
      result := list.add(("liq_cross_start_next", string(liq_cross_start_next)), result())
      result := list.assoc.remove("liq_fade_in", result())
      result := list.add(("liq_fade_in", string(liq_fade_in)), result())
      result := list.assoc.remove("liq_fade_out", result())
      result := list.add(("liq_fade_out", string(liq_fade_out)), result())

      # now remove everything that’s not autocue-relevant
      # so we don’t blow up decoder and annotation metadata
      def fl(k, _) =
        tags = ["duration", "replaygain_track_gain", "replaygain_reference_loudness"]
        string.contains(prefix="liq_", k) or list.mem(k, tags)
      end
      result := list.assoc.filter((fl), result())

      l = list.sort.natural(stdlib_metadata.cover.remove(result()))
      log.important(label=label, 'Metadata added/corrected for "#{filename}":')
      list.iter(fun(v) -> log.important(label=label, "#{v}"), l)

      # for optional meta elements that aren’t guaranteed to be in result,
      # like replaygain_track_gain, replaygain_reference_loudness
      def optional_meta(lbl, meta) =
        if list.assoc.mem(lbl, meta) then
          [(lbl, list.assoc(lbl, meta))]
        else
          []
        end
      end

      extra_metadata =
        [
          ("duration", list.assoc("duration", result())),
          ("liq_amplify", list.assoc("liq_amplify", result())),
          ("liq_amplify_adjustment", list.assoc("liq_amplify_adjustment", result())),
          ("liq_cue_duration", list.assoc("liq_cue_duration", result())),
          ("liq_longtail", list.assoc("liq_longtail", result())),
          ("liq_sustained_ending", list.assoc("liq_sustained_ending", result())),
          ("liq_loudness", list.assoc("liq_loudness", result())),
          ("liq_loudness_range", list.assoc("liq_loudness_range", result())),
          ("liq_reference_loudness", list.assoc("liq_reference_loudness", result())),
          ("liq_blankskip", list.assoc("liq_blankskip", result())),
          ("liq_blank_skipped", list.assoc("liq_blank_skipped", result())),
          ("liq_true_peak", list.assoc("liq_true_peak", result())),
          ("liq_true_peak_db", list.assoc("liq_true_peak_db", result())),
          ...optional_meta("replaygain_track_gain", result()),
          ...optional_meta("replaygain_track_peak", result()),
          ...optional_meta("replaygain_track_range", result()),
          ...optional_meta("replaygain_reference_loudness", result())
        ]

      {
        amplify = list.assoc("liq_amplify", result()),
        cue_in = float_of_string(list.assoc("liq_cue_in", result())),
        cue_out = float_of_string(list.assoc("liq_cue_out", result())),
        fade_in = float_of_string(list.assoc("liq_fade_in", result())),
        fade_out = float_of_string(list.assoc("liq_fade_out", result())),
        start_next = float_of_string(list.assoc("liq_cross_start_next", result())),
        extra_metadata=extra_metadata
      }
    else
      log(
        level=2,
        label=label,
        'No autocue data found for "#{filename}"'
      )
      null()
    end
  end
end

# set this so annotations (priority 5) can still override autocue values
settings.autocue.metadata.priority := 10
settings.autocue.preferred := "cue_file"
# use our values in any case
settings.autocue.amplify_behavior := "keep"
# avoid dead air from reconcile, reset default 3.0s to our fade_out duration
settings.fade.out.duration := settings.autocue.cue_file.fade_out()
autocue.register(name="cue_file", cue_file)

# --- Copy-paste Azuracast LS Config, second input box END ---

# Don't forget to add your settings after this and do the check!
# Here's a list of all possible settings with their defaults

# settings.autocue.cue_file.path := "cue_file"
# settings.autocue.cue_file.fade_in := 0.1  # seconds
# settings.autocue.cue_file.fade_out := 2.5  # seconds
# settings.autocue.cue_file.timeout := 60.0  # seconds
# settings.autocue.cue_file.target := -18.0  # LUFS
# settings.autocue.cue_file.silence := -42.0  # LU below track loudness
# settings.autocue.cue_file.overlay := -8.0  # LU below track loudness
# settings.autocue.cue_file.longtail := 15.0  # seconds
# settings.autocue.cue_file.overlay_longtail := -15.0  # extra LU
# settings.autocue.cue_file.sustained_loudness_drop := 40.0  # max. percent drop to be considered sustained
# settings.autocue.cue_file.noclip := false  # clipping prevention like loudgain's `-k`
# settings.autocue.cue_file.blankskip := 0.0  # skip silence in tracks
# settings.autocue.cue_file.unify_loudness_correction := true  # unify `replaygain_track_gain` & `liq_amplify`
# settings.autocue.cue_file.write_tags := false  # write liq_* tags back to file
# settings.autocue.cue_file.write_replaygain := false  # write ReplayGain tags back to file
# settings.autocue.cue_file.force_analysis := false  # force re-analysis even if tags found
# settings.autocue.cue_file.nice := false  # Linux/MacOS only: Use NI=18 for analysis
# settings.autocue.cue_file.use_json_metadata := true  # pass metadata to `cue_file` as JSON

# Check Autocue setup, print result, shutdown if problems
# The check results will also be in the log.
# Returns a bool: true=ok, false=error. We ignore that here.
# set `print=true` for standalone scripts, `false` for AzuraCast
# ignore(check_autocue_setup(shutdown=true, print=false))

# `enable_autocue_metadata()` will autocue ALL files Liquidsoap processes.
# You can disable it for selected sources using 'annotate:liq_cue_file=false'.
# Remember you won't get `liq_amplify` data then -- expect loudness jumps!
# enable_autocue_metadata()
