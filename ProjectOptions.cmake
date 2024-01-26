include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(skript_2_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(skript_2_setup_options)
  option(skript_2_ENABLE_HARDENING "Enable hardening" ON)
  option(skript_2_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    skript_2_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    skript_2_ENABLE_HARDENING
    OFF)

  skript_2_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR skript_2_PACKAGING_MAINTAINER_MODE)
    option(skript_2_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(skript_2_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(skript_2_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(skript_2_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(skript_2_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(skript_2_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(skript_2_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(skript_2_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(skript_2_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(skript_2_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(skript_2_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(skript_2_ENABLE_PCH "Enable precompiled headers" OFF)
    option(skript_2_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(skript_2_ENABLE_IPO "Enable IPO/LTO" ON)
    option(skript_2_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(skript_2_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(skript_2_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(skript_2_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(skript_2_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(skript_2_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(skript_2_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(skript_2_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(skript_2_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(skript_2_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(skript_2_ENABLE_PCH "Enable precompiled headers" OFF)
    option(skript_2_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      skript_2_ENABLE_IPO
      skript_2_WARNINGS_AS_ERRORS
      skript_2_ENABLE_USER_LINKER
      skript_2_ENABLE_SANITIZER_ADDRESS
      skript_2_ENABLE_SANITIZER_LEAK
      skript_2_ENABLE_SANITIZER_UNDEFINED
      skript_2_ENABLE_SANITIZER_THREAD
      skript_2_ENABLE_SANITIZER_MEMORY
      skript_2_ENABLE_UNITY_BUILD
      skript_2_ENABLE_CLANG_TIDY
      skript_2_ENABLE_CPPCHECK
      skript_2_ENABLE_COVERAGE
      skript_2_ENABLE_PCH
      skript_2_ENABLE_CACHE)
  endif()

  skript_2_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (skript_2_ENABLE_SANITIZER_ADDRESS OR skript_2_ENABLE_SANITIZER_THREAD OR skript_2_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(skript_2_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(skript_2_global_options)
  if(skript_2_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    skript_2_enable_ipo()
  endif()

  skript_2_supports_sanitizers()

  if(skript_2_ENABLE_HARDENING AND skript_2_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR skript_2_ENABLE_SANITIZER_UNDEFINED
       OR skript_2_ENABLE_SANITIZER_ADDRESS
       OR skript_2_ENABLE_SANITIZER_THREAD
       OR skript_2_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${skript_2_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${skript_2_ENABLE_SANITIZER_UNDEFINED}")
    skript_2_enable_hardening(skript_2_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(skript_2_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(skript_2_warnings INTERFACE)
  add_library(skript_2_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  skript_2_set_project_warnings(
    skript_2_warnings
    ${skript_2_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(skript_2_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(skript_2_options)
  endif()

  include(cmake/Sanitizers.cmake)
  skript_2_enable_sanitizers(
    skript_2_options
    ${skript_2_ENABLE_SANITIZER_ADDRESS}
    ${skript_2_ENABLE_SANITIZER_LEAK}
    ${skript_2_ENABLE_SANITIZER_UNDEFINED}
    ${skript_2_ENABLE_SANITIZER_THREAD}
    ${skript_2_ENABLE_SANITIZER_MEMORY})

  set_target_properties(skript_2_options PROPERTIES UNITY_BUILD ${skript_2_ENABLE_UNITY_BUILD})

  if(skript_2_ENABLE_PCH)
    target_precompile_headers(
      skript_2_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(skript_2_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    skript_2_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(skript_2_ENABLE_CLANG_TIDY)
    skript_2_enable_clang_tidy(skript_2_options ${skript_2_WARNINGS_AS_ERRORS})
  endif()

  if(skript_2_ENABLE_CPPCHECK)
    skript_2_enable_cppcheck(${skript_2_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(skript_2_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    skript_2_enable_coverage(skript_2_options)
  endif()

  if(skript_2_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(skript_2_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(skript_2_ENABLE_HARDENING AND NOT skript_2_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR skript_2_ENABLE_SANITIZER_UNDEFINED
       OR skript_2_ENABLE_SANITIZER_ADDRESS
       OR skript_2_ENABLE_SANITIZER_THREAD
       OR skript_2_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    skript_2_enable_hardening(skript_2_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
