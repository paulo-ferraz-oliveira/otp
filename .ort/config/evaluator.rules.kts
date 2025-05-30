/*
 * %CopyrightBegin%
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Copyright Ericsson AB 2024-2025. All Rights Reserved.
 * Copyright (c) 2021 The Elixir Team
 * Copyright (C) 2019 The ORT Project Authors (see <https://github.com/oss-review-toolkit/ort/blob/main/NOTICE>)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * %CopyrightEnd%
 */

 // Docs: https://oss-review-toolkit.org/ort/docs/configuration/evaluator-rules

val allowedLicenses = licenseClassifications.licensesByCategory["allow"].orEmpty()
val reviewLicenses = licenseClassifications.licensesByCategory["review"].orEmpty()

// The complete set of licenses covered by policy rules.
val handledLicenses = listOf(
    allowedLicenses,
    reviewLicenses
).flatten().let {
    it.getDuplicates().let { duplicates ->
        require(duplicates.isEmpty()) {
            "The classifications for the following licenses overlap: $duplicates"
        }
    }

    it.toSet()
}

fun PackageRule.howToFixDefault() = """
      * Check if this license violation is intended
      * Adjust evaluation rules in `.ort/config/evaluator.rules.kts`
    """.trimIndent()

fun PackageRule.LicenseRule.isHandled() =
  object : RuleMatcher {
    override val description = "isHandled($license)"

    override fun matches() = license in handledLicenses
        && ("-exception" !in license.toString() || " WITH " in license.toString())
  }

fun PackageRule.LicenseRule.isAllowed() =
  object : RuleMatcher {
    override val description = "isAllowed($license)"

    override fun matches() = license in allowedLicenses
  }

fun RuleSet.unhandledLicenseRule() = packageRule("UNHANDLED_LICENSE") {
  // Do not trigger this rule on packages that have been excluded in the .ort.yml.
  require {
    -isExcluded()
  }

  // Define a rule that is executed for each license of the package.
  licenseRule("UNHANDLED_LICENSE", LicenseView.CONCLUDED_OR_DECLARED_AND_DETECTED) {
    require {
      -isExcluded()
      -isHandled()
    }

    var filenames = "";

    resolvedLicense.locations.forEach {
        filenames += " " + it.location.path;
    }

    // Throw an error message including guidance how to fix the issue.
    error(
      "The license $license is currently not covered by policy rules. " +
        "The license was ${licenseSource.name.lowercase()} in package " +
        "${pkg.metadata.id.toCoordinates()}. " +
        "The files that have the license are: ${filenames}",
      howToFixDefault()
    )
  }
}

fun RuleSet.unmappedDeclaredLicenseRule() = packageRule("UNMAPPED_DECLARED_LICENSE") {
  require {
    -isExcluded()
  }

  resolvedLicenseInfo.licenseInfo.declaredLicenseInfo.processed.unmapped.forEach { unmappedLicense ->
    warning(
      "The declared license '$unmappedLicense' could not be mapped to a valid license or parsed as an SPDX " +
        "expression. The license was found in package ${pkg.metadata.id.toCoordinates()}.",
      howToFixDefault()
    )
  }
}

val ruleSet = ruleSet(ortResult, licenseInfoResolver, resolutionProvider) {
  unhandledLicenseRule()
  unmappedDeclaredLicenseRule()
}

ruleViolations += ruleSet.violations